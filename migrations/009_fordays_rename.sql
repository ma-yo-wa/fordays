-- =====================================================================
--  009 — Someday → Fordays
--
--  Space default, signup insert, existing default names, and the push
--  fallback that still said “Open Someday…”. Historical migrations
--  already applied in production will not re-run, so this is the live
--  cutover.
-- =====================================================================

alter table public.spaces alter column name set default 'Fordays';

update public.spaces
   set name = 'Fordays'
 where name = 'Someday';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  name text;
begin
  name := coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1));

  insert into public.profiles (id, display_name)
  values (new.id, name)
  on conflict (id) do nothing;

  insert into public.spaces (partner_1_id, name)
  values (new.id, 'Fordays');

  return new;
end;
$$;

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

  select case when s.partner_1_id = actor then s.partner_2_id else s.partner_1_id end
    into recipient
    from public.spaces s
   where s.id = new.space_id;

  if recipient is null then
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

  perform private.enqueue_push(recipient, new.space_id, kind, title, body, new.id);
  return new;
end;
$$;
