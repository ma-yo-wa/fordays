-- 012 — Past Orbs: restore solo spaces and permanently delete frozen snapshots

-- 1. Restore a frozen space back to active planning (for solo / admin spaces)
create or replace function public.restore_space(sid uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  is_admin boolean;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select (role = 'admin') into is_admin
    from public.space_members
   where space_id = sid and user_id = auth.uid();

  if not coalesce(is_admin, false) then
    raise exception 'You cannot restore this space';
  end if;

  update public.spaces
     set frozen = false
   where id = sid;
end;
$$;

revoke all on function public.restore_space(uuid) from public;
grant execute on function public.restore_space(uuid) to authenticated;

-- 2. Permanently delete a frozen snapshot
create or replace function public.delete_frozen_space(sid uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  is_froz boolean;
  is_admin boolean;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select frozen into is_froz
    from public.spaces
   where id = sid;

  if not coalesce(is_froz, false) then
    raise exception 'Only frozen spaces can be permanently deleted';
  end if;

  select (role = 'admin') into is_admin
    from public.space_members
   where space_id = sid and user_id = auth.uid();

  if not coalesce(is_admin, false) then
    raise exception 'You cannot delete this space';
  end if;

  delete from public.activities where space_id = sid;
  delete from public.external_events where space_id = sid;
  delete from public.space_members where space_id = sid;
  delete from public.spaces where id = sid;
end;
$$;

revoke all on function public.delete_frozen_space(uuid) from public;
grant execute on function public.delete_frozen_space(uuid) to authenticated;

-- 3. Improve snapshot naming so frozen copies remember who they were with
create or replace function public.snapshot_space_for(sid uuid, uid uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  src public.spaces;
  copy_id uuid;
  derived_name text;
begin
  select * into src from public.spaces where id = sid;
  if src.id is null then
    raise exception 'No space';
  end if;

  -- If source has a custom name (not Fordays / Someday), keep it.
  -- Otherwise, if it was with other people, inherit their names so the snapshot has an identity.
  if src.name is not null and src.name <> 'Fordays' and src.name <> 'Someday' and src.name <> '' then
    derived_name := src.name;
  else
    select string_agg(p.display_name, ', ' order by sm.joined_at)
      into derived_name
      from public.space_members sm
      join public.profiles p on p.id = sm.user_id
     where sm.space_id = sid and sm.user_id <> uid;

    if derived_name is null or derived_name = '' then
      derived_name := coalesce(src.name, 'Fordays');
    end if;
  end if;

  insert into public.spaces (partner_1_id, name, frozen, forked_from)
  values (uid, derived_name, true, sid)
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

revoke all on function public.snapshot_space_for(uuid, uuid) from public;
grant execute on function public.snapshot_space_for(uuid, uuid) to authenticated;
