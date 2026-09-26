-- =====================================================================
--  020 — Notifications: one device per person, iOS alongside web
--
--  1. A device belongs to a person, not to one Orb. It hears from every
--     Orb they are in. space_id stays on the table for old rows only.
--  2. iOS devices live in the same table (platform = 'ios'), keyed by
--     'apns:<token>' in endpoint so the unique index still holds.
--  3. Triggers send facts (who, what, when), not finished sentences.
--     push-fan-out writes the words per device, so a time reads in that
--     device's own time zone instead of the server's UTC.
--  4. "joined" watches space_members. The old partner_2_id trigger never
--     fired for anyone after the first two.
--  5. Copy: no emoji, no exclamation marks, plan / day / Someday.
-- =====================================================================

-- 1. Devices ----------------------------------------------------------

alter table public.push_subscriptions
  alter column space_id drop not null,
  alter column p256dh  drop not null,
  alter column auth    drop not null,
  add column if not exists platform  text not null default 'web',
  add column if not exists apns_env  text,
  add column if not exists time_zone text;

alter table public.push_subscriptions
  drop constraint if exists push_subscriptions_platform_check;
alter table public.push_subscriptions
  add constraint push_subscriptions_platform_check
  check (platform in ('web', 'ios'));

-- A device signed into another account last time moves to whoever is
-- signed in now. RLS can't do that (the old row isn't ours), so this
-- runs as definer and only ever assigns the row to auth.uid().
create or replace function public.register_push_device(
  device_endpoint text,
  device_platform text default 'web',
  device_p256dh   text default null,
  device_auth     text default null,
  device_apns_env text default null,
  device_tz       text default null,
  device_agent    text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  if coalesce(btrim(device_endpoint), '') = '' then
    raise exception 'Missing endpoint';
  end if;

  insert into public.push_subscriptions
    (user_id, endpoint, platform, p256dh, auth, apns_env, time_zone, user_agent, last_seen)
  values
    (auth.uid(), device_endpoint, device_platform, device_p256dh, device_auth,
     device_apns_env, device_tz, left(device_agent, 180), now())
  on conflict (endpoint) do update
    set user_id    = excluded.user_id,
        space_id   = null,
        platform   = excluded.platform,
        p256dh     = excluded.p256dh,
        auth       = excluded.auth,
        apns_env   = excluded.apns_env,
        time_zone  = excluded.time_zone,
        user_agent = excluded.user_agent,
        last_seen  = now();
end;
$$;

revoke execute on function public.register_push_device(text, text, text, text, text, text, text) from anon;
grant  execute on function public.register_push_device(text, text, text, text, text, text, text) to authenticated;

-- Old rows were one per (device, Orb) but endpoint was already unique,
-- so each device has one row; it just stops caring which Orb.
update public.push_subscriptions set space_id = null where space_id is not null;

-- 2. Queue a push -----------------------------------------------------

-- Facts only. push-fan-out turns them into words per device.
create or replace function private.enqueue_push_event(
  recipient uuid,
  space     uuid,
  kind      text,
  activity  uuid,
  facts     jsonb
)
returns void
language plpgsql
security definer
set search_path = private, net, extensions, public
as $$
declare
  fn_url     text := private.cfg('push_fn_url');
  fn_key     text := private.cfg('push_fn_key');
  orb_name   text;
  shared_orbs int;
begin
  if recipient is null or fn_url is null or fn_key is null then
    return;
  end if;

  -- Name the Orb only when they're in more than one shared Orb, so a
  -- couple with one shared notebook never sees it.
  select count(*) into shared_orbs
    from public.space_members m
    join public.spaces s on s.id = m.space_id
   where m.user_id = recipient
     and not coalesce(s.frozen, false)
     and (select count(*) from public.space_members o where o.space_id = s.id) > 1;

  if shared_orbs > 1 then
    select nullif(btrim(name), '') into orb_name from public.spaces where id = space;
  end if;

  begin
    perform net.http_post(
      url     := fn_url,
      headers := jsonb_build_object(
                   'Content-Type',  'application/json',
                   'Authorization', 'Bearer ' || fn_key
                 ),
      body    := jsonb_build_object(
                   'recipient_id', recipient,
                   'space_id',     space,
                   'activity_id',  activity,
                   'kind',         kind,
                   'facts',        facts || jsonb_build_object('orb', orb_name)
                 ),
      timeout_milliseconds := 5000
    );
  exception
    when others then
      raise warning 'enqueue_push_event failed: %', sqlerrm;
  end;
end;
$$;

-- First word of a display name: "Tess", not "Tess Adeyemi".
create or replace function private.first_name(uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(split_part(btrim(p.display_name), ' ', 1), ''),
    'Someone'
  )
  from (select 1) one
  left join public.profiles p on p.id = uid;
$$;

-- 3. Plans ------------------------------------------------------------

create or replace function public.notify_partner()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  kind      text;
  actor     uuid := coalesce(auth.uid(), new.created_by);
  recipient uuid;
  facts     jsonb;
begin
  if tg_op = 'UPDATE' and old.space_id is distinct from new.space_id then
    -- Moved in from another Orb: new to everyone here.
    kind := case when new.date_time is null then 'idea' else 'scheduled' end;
  elsif tg_op = 'UPDATE'
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
        and old.date_time is not null and new.date_time is not null
        and (old.date_time is distinct from new.date_time
             or old.all_day is distinct from new.all_day) then
    kind := 'rescheduled';
  elsif tg_op = 'UPDATE'
        and new.description is distinct from old.description
        and coalesce(btrim(new.description), '') <> '' then
    kind := 'notes';
  else
    return new;
  end if;

  facts := jsonb_build_object(
    'actor', private.first_name(actor),
    'title', new.title,
    'note',  case
               when kind = 'suggested' then nullif(btrim(new.suggested_note), '')
               when kind in ('idea', 'notes') then nullif(btrim(new.description), '')
             end,
    'at',    case when kind = 'suggested' then new.suggested_date_time else new.date_time end,
    'all_day', case when kind = 'suggested' then coalesce(new.suggested_all_day, false)
                    else coalesce(new.all_day, false) end
  );

  for recipient in
    select m.user_id
      from public.space_members m
     where m.space_id = new.space_id
       and m.user_id <> actor
  loop
    perform private.enqueue_push_event(recipient, new.space_id, kind, new.id, facts);
  end loop;

  return new;
end;
$$;

-- 4. Joined -----------------------------------------------------------

drop trigger if exists spaces_notify_partner_joined on public.spaces;
drop function if exists public.notify_partner_joined();

create or replace function public.notify_member_joined()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  recipient uuid;
  facts     jsonb;
begin
  -- Frozen copies are made for someone leaving; nobody "joins" those.
  if exists (select 1 from public.spaces where id = new.space_id and frozen) then
    return new;
  end if;

  facts := jsonb_build_object(
    'actor', private.first_name(new.user_id),
    'orb_name', (select nullif(btrim(name), '') from public.spaces where id = new.space_id)
  );

  for recipient in
    select m.user_id
      from public.space_members m
     where m.space_id = new.space_id
       and m.user_id <> new.user_id
  loop
    perform private.enqueue_push_event(recipient, new.space_id, 'joined', null, facts);
  end loop;

  return new;
end;
$$;

drop trigger if exists space_members_notify_joined on public.space_members;
create trigger space_members_notify_joined
  after insert on public.space_members
  for each row execute function public.notify_member_joined();

-- Never attached to a trigger (notify_partner is); keep it from confusing
-- the next reader.
drop function if exists private.notify_activity_change();

notify pgrst, 'reload schema';
