-- =====================================================================
--  010 — Spaces: members, many notebooks, leave keeps a frozen copy
--
--  A space is the notebook for a we. You can be in several. Join does
--  not delete your other spaces. Leave = others keep the live book;
--  you keep a frozen copy. Delete only when you are the last member.
-- =====================================================================

alter table public.spaces
  add column if not exists frozen boolean not null default false;

alter table public.spaces
  add column if not exists forked_from uuid references public.spaces(id) on delete set null;

create table if not exists public.space_members (
  space_id   uuid not null references public.spaces(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'member' check (role in ('admin', 'member')),
  joined_at  timestamptz not null default now(),
  primary key (space_id, user_id)
);

create index if not exists space_members_user_idx on public.space_members(user_id);

insert into public.space_members (space_id, user_id, role, joined_at)
select s.id, s.partner_1_id, 'admin', s.created_at
  from public.spaces s
 where s.partner_1_id is not null
on conflict do nothing;

insert into public.space_members (space_id, user_id, role, joined_at)
select s.id, s.partner_2_id, 'member', s.created_at
  from public.spaces s
 where s.partner_2_id is not null
on conflict do nothing;

create or replace function public.is_space_member(target_space uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.space_members m
    where m.space_id = target_space and m.user_id = auth.uid()
  );
$$;

create or replace function public.sync_space_partner_columns(sid uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  admin_id uuid;
  other_id uuid;
  n int;
begin
  select count(*) into n from public.space_members where space_id = sid;
  select user_id into admin_id
    from public.space_members
   where space_id = sid
   order by case when role = 'admin' then 0 else 1 end, joined_at
   limit 1;

  if n = 2 then
    select user_id into other_id
      from public.space_members
     where space_id = sid and user_id <> admin_id
     limit 1;
  else
    other_id := null;
  end if;

  if admin_id is not null then
    update public.spaces
       set partner_1_id = admin_id,
           partner_2_id = other_id
     where id = sid;
  end if;
end;
$$;

-- Membership is the source of truth for who can see a space.
drop policy if exists "read own space" on public.spaces;
create policy "read own space" on public.spaces
  for select using (public.is_space_member(id));

drop policy if exists "members update space" on public.spaces;
create policy "members update space" on public.spaces
  for update using (public.is_space_member(id) and not frozen);

drop policy if exists "owner deletes space" on public.spaces;

alter table public.space_members enable row level security;

drop policy if exists "read members of my spaces" on public.space_members;
create policy "read members of my spaces" on public.space_members
  for select using (public.is_space_member(space_id));

drop policy if exists "read own and partner profile" on public.profiles;
create policy "read own and partner profile" on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1 from public.space_members mine
      join public.space_members theirs
        on theirs.space_id = mine.space_id
     where mine.user_id = auth.uid()
       and theirs.user_id = profiles.id
    )
  );

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  name text;
  sid uuid;
begin
  name := coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1));

  insert into public.profiles (id, display_name)
  values (new.id, name)
  on conflict (id) do nothing;

  insert into public.spaces (partner_1_id, name)
  values (new.id, 'Fordays')
  returning id into sid;

  insert into public.space_members (space_id, user_id, role)
  values (sid, new.id, 'admin');

  return new;
end;
$$;

create or replace function public.peek_invite(code text)
returns table (space_id uuid, space_name text, inviter_name text, is_open boolean)
language sql
stable
security definer set search_path = public
as $$
  select s.id,
         s.name,
         p.display_name,
         not s.frozen
    from public.spaces s
    join public.space_members m
      on m.space_id = s.id and m.role = 'admin'
    join public.profiles p on p.id = m.user_id
   where s.invite_code = code
   order by m.joined_at
   limit 1;
$$;

create or replace function public.create_space(p_name text default 'Fordays')
returns public.spaces
language plpgsql
security definer set search_path = public
as $$
declare
  created public.spaces;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  insert into public.spaces (partner_1_id, name)
  values (auth.uid(), coalesce(nullif(btrim(p_name), ''), 'Fordays'))
  returning * into created;

  insert into public.space_members (space_id, user_id, role)
  values (created.id, auth.uid(), 'admin');

  return created;
end;
$$;

revoke all on function public.create_space(text) from public;
grant execute on function public.create_space(text) to authenticated;

-- Join adds a seat. It never deletes your other notebooks.
create or replace function public.join_space(code text)
returns public.spaces
language plpgsql
security definer set search_path = public
as $$
declare
  target public.spaces;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select * into target from public.spaces where invite_code = code;
  if target.id is null then
    raise exception 'No space found for that invite code'
      using errcode = 'no_data_found';
  end if;

  if target.frozen then
    raise exception 'This space is a copy from when someone left'
      using errcode = 'check_violation';
  end if;

  if exists (
    select 1 from public.space_members
     where space_id = target.id and user_id = auth.uid()
  ) then
    return target;
  end if;

  insert into public.space_members (space_id, user_id, role)
  values (target.id, auth.uid(), 'member');

  perform public.sync_space_partner_columns(target.id);
  select * into target from public.spaces where id = target.id;
  return target;
end;
$$;

-- Old path that moved items and dropped your space — keep the name,
-- but do not destroy other notebooks. Same as join_space.
create or replace function public.join_space_bringing_items(code text)
returns public.spaces
language plpgsql
security definer set search_path = public
as $$
begin
  return public.join_space(code);
end;
$$;

create or replace function public.snapshot_space_for(sid uuid, uid uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  src public.spaces;
  copy_id uuid;
begin
  select * into src from public.spaces where id = sid;
  if src.id is null then
    raise exception 'No space';
  end if;

  insert into public.spaces (partner_1_id, name, frozen, forked_from)
  values (uid, src.name, true, sid)
  returning id into copy_id;

  insert into public.space_members (space_id, user_id, role)
  values (copy_id, uid, 'admin');

  alter table public.activities disable trigger user;

  insert into public.activities (
    space_id, title, description, image_url, created_by,
    date_time, ends_at, all_day, created_at, updated_at
  )
  select
    copy_id, title, description, image_url, created_by,
    date_time, ends_at, all_day, created_at, updated_at
  from public.activities
  where space_id = sid;

  alter table public.activities enable trigger user;

  return copy_id;
end;
$$;

create or replace function public.leave_space(sid uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  others int;
  copy_id uuid;
  next_admin uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if not exists (
    select 1 from public.space_members
     where space_id = sid and user_id = auth.uid()
  ) then
    raise exception 'You are not in that space';
  end if;

  select count(*) into others
    from public.space_members
   where space_id = sid and user_id <> auth.uid();

  if others = 0 then
    delete from public.spaces where id = sid;
    return null;
  end if;

  copy_id := public.snapshot_space_for(sid, auth.uid());

  delete from public.space_members
   where space_id = sid and user_id = auth.uid();

  if not exists (
    select 1 from public.space_members
     where space_id = sid and role = 'admin'
  ) then
    select user_id into next_admin
      from public.space_members
     where space_id = sid
     order by joined_at
     limit 1;
    if next_admin is not null then
      update public.space_members
         set role = 'admin'
       where space_id = sid and user_id = next_admin;
    end if;
  end if;

  perform public.sync_space_partner_columns(sid);
  return copy_id;
end;
$$;

revoke all on function public.leave_space(uuid) from public;
grant execute on function public.leave_space(uuid) to authenticated;

create or replace function public.remove_space_member(sid uuid, uid uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  n int;
  copy_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if uid = auth.uid() then
    return public.leave_space(sid);
  end if;

  if not exists (
    select 1 from public.space_members
     where space_id = sid and user_id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Only an admin can remove someone';
  end if;

  select count(*) into n from public.space_members where space_id = sid;
  if n < 3 then
    raise exception 'In a pair, leave — don’t remove';
  end if;

  if not exists (
    select 1 from public.space_members
     where space_id = sid and user_id = uid
  ) then
    raise exception 'They are not in that space';
  end if;

  copy_id := public.snapshot_space_for(sid, uid);

  delete from public.space_members
   where space_id = sid and user_id = uid;

  perform public.sync_space_partner_columns(sid);
  return copy_id;
end;
$$;

revoke all on function public.remove_space_member(uuid, uuid) from public;
grant execute on function public.remove_space_member(uuid, uuid) to authenticated;

-- Push the other people in the space, not only partner_2.
create or replace function public.notify_partner()
returns trigger
language plpgsql
security definer set search_path = public, private
as $$
declare
  kind        text;
  actor       uuid := coalesce(auth.uid(), new.created_by);
  recipient   uuid;
  actor_name  text;
  title       text;
  body        text;
begin
  if tg_op = 'UPDATE'
     and new.suggested_date_time is not null
     and new.suggested_by is not null
     and (
       old.suggested_date_time is distinct from new.suggested_date_time
       or old.suggested_by is distinct from new.suggested_by
       or old.suggested_ends_at is distinct from new.suggested_ends_at
     ) then
    kind := 'suggested';
    actor := new.suggested_by;
  elsif tg_op = 'UPDATE'
        and old.suggested_date_time is not null
        and new.suggested_date_time is null
        and new.date_time is not distinct from old.suggested_date_time
        and new.date_time is distinct from old.date_time then
    kind := 'suggestion_accepted';
  elsif tg_op = 'INSERT' and new.date_time is null then
    kind := 'idea';
  elsif (tg_op = 'INSERT' and new.date_time is not null)
     or (tg_op = 'UPDATE' and old.date_time is null and new.date_time is not null
         and not (old.suggested_date_time is not null
                  and new.date_time is not distinct from old.suggested_date_time)) then
    kind := 'scheduled';
  elsif tg_op = 'UPDATE'
        and new.description is distinct from old.description
        and coalesce(btrim(new.description), '') <> '' then
    kind := 'notes';
  else
    return new;
  end if;

  select display_name into actor_name from public.profiles where id = actor;
  actor_name := coalesce(actor_name, 'Someone');

  if kind = 'suggested' then
    title := '💬 ' || actor_name || ' suggested a new time for ' || new.title;
    body  := case
               when coalesce(btrim(new.suggested_note), '') <> '' then left(new.suggested_note, 120)
               when new.suggested_all_day
                 then to_char(new.suggested_date_time at time zone 'UTC', 'Dy, Mon DD')
               else to_char(new.suggested_date_time at time zone 'UTC', 'Dy, Mon DD')
                    || ' at ' || to_char(new.suggested_date_time at time zone 'UTC', 'HH12:MI AM')
             end;
  elsif kind = 'suggestion_accepted' then
    title := '✅ ' || actor_name || ' accepted your time for ' || new.title;
    body  := case when new.all_day
                  then to_char(new.date_time at time zone 'UTC', 'Dy, Mon DD')
                  else to_char(new.date_time at time zone 'UTC', 'Dy, Mon DD')
                       || ' at ' || to_char(new.date_time at time zone 'UTC', 'HH12:MI AM')
             end;
  elsif kind = 'idea' then
    title := '💡 ' || actor_name || ' added “' || new.title || '” to the bucket';
    body  := case
               when coalesce(btrim(new.description), '') <> '' then left(new.description, 120)
               else 'Open Fordays when you’re free'
             end;
  elsif kind = 'scheduled' then
    title := '📅 ' || actor_name || ' locked in a date for ' || new.title || '!';
    body  := to_char(new.date_time at time zone 'UTC', 'Dy, Mon DD')
             || case when new.all_day then '' else ' at ' ||
                  to_char(new.date_time at time zone 'UTC', 'HH12:MI AM') end;
  else
    title := '✏️ ' || actor_name || ' updated the notes for ' || new.title || '.';
    body  := left(new.description, 120);
  end if;

  for recipient in
    select m.user_id
      from public.space_members m
     where m.space_id = new.space_id
       and m.user_id <> actor
  loop
    perform private.enqueue_push(recipient, new.space_id, kind, title, body, new.id);
  end loop;

  return new;
end;
$$;

drop policy if exists "members insert activities" on public.activities;
create policy "members insert activities" on public.activities
  for insert with check (
    public.is_space_member(space_id)
    and created_by = auth.uid()
    and exists (select 1 from public.spaces s where s.id = space_id and not s.frozen)
  );

drop policy if exists "members update activities" on public.activities;
create policy "members update activities" on public.activities
  for update using (
    public.is_space_member(space_id)
    and exists (select 1 from public.spaces s where s.id = space_id and not s.frozen)
  )
  with check (public.is_space_member(space_id));

drop policy if exists "members delete activities" on public.activities;
create policy "members delete activities" on public.activities
  for delete using (
    public.is_space_member(space_id)
    and exists (select 1 from public.spaces s where s.id = space_id and not s.frozen)
  );

