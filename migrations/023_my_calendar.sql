-- =====================================================================
--  023 — Your calendar is yours
--
--  An imported Google / Apple / Outlook event belongs to the person who
--  imported it, not to an Orb. It lives once in my_events, only its owner
--  can read it, it reminds them and it's in their morning summary. Nobody
--  else ever sees it: no Busy, no sharing switch.
--
--  Timed events keep real instants; all-day events are plain dates (the
--  last day included), so they no longer drift with the time zone.
--
--  external_events stays until both clients read my_events. Until then a
--  trigger copies what older clients write there into my_events. A later
--  cleanup drops it with shared_with_space and toggle_external_event_share.
-- =====================================================================

create table if not exists public.my_events (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null default auth.uid()
                 references public.profiles(id) on delete cascade,
  source         text not null check (source in ('google', 'apple', 'outlook')),
  -- The provider's calendar id, so each ticked calendar replaces on its own.
  calendar_id    text not null,
  calendar_name  text not null,
  -- The provider's event id (one per occurrence).
  source_id      text not null,
  title          text,
  location       text,
  starts_at      timestamptz,
  ends_at        timestamptz,
  start_date     date,
  end_date       date,
  updated_at     timestamptz not null default now(),
  unique (owner_id, source, calendar_id, source_id),
  -- Timed has instants, all-day has dates, never both.
  check (
    (starts_at is not null and start_date is null and end_date is null)
    or (starts_at is null and ends_at is null and start_date is not null
        and end_date is not null and end_date >= start_date)
  )
);

create index if not exists my_events_owner_timed_idx
  on public.my_events (owner_id, starts_at) where starts_at is not null;
create index if not exists my_events_owner_day_idx
  on public.my_events (owner_id, start_date) where start_date is not null;

alter table public.my_events enable row level security;

drop policy if exists "owner reads my events" on public.my_events;
create policy "owner reads my events" on public.my_events
  for select using (owner_id = auth.uid());

drop policy if exists "owner writes my events" on public.my_events;
create policy "owner writes my events" on public.my_events
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

grant select, insert, update, delete on public.my_events to authenticated;

-- ---------------------------------------------------------------------
--  Once: copy what's there. The same event came in through every Orb it
--  was imported into (Gym ×4); keep one, the freshest. All-day rows were
--  stored at noon UTC or local midnight, so read their date in the
--  owner's time zone. Their calendar id isn't known yet, so it's the
--  name; a client's first sync replaces these with real ids.
-- ---------------------------------------------------------------------

insert into public.my_events
  (owner_id, source, calendar_id, calendar_name, source_id, title, location,
   starts_at, ends_at, start_date, end_date, updated_at)
select distinct on (e.owner_id, e.calendar_source, e.calendar_name, e.source_id)
       e.owner_id, e.calendar_source, e.calendar_name, e.calendar_name, e.source_id,
       e.title, e.location,
       case when e.all_day then null else e.starts_at end,
       case when e.all_day then null else e.ends_at end,
       case when e.all_day
            then (e.starts_at at time zone coalesce(np.time_zone, 'UTC'))::date end,
       case when e.all_day
            then greatest((e.ends_at at time zone coalesce(np.time_zone, 'UTC'))::date,
                          (e.starts_at at time zone coalesce(np.time_zone, 'UTC'))::date) end,
       e.updated_at
  from public.external_events e
  left join public.notification_prefs np on np.user_id = e.owner_id
 order by e.owner_id, e.calendar_source, e.calendar_name, e.source_id, e.updated_at desc
on conflict (owner_id, source, calendar_id, source_id) do nothing;

-- ---------------------------------------------------------------------
--  Sync: one calendar at a time, whole. Anything not in p_events is gone
--  (deleted or declined at the source). Each event is
--  {source_id, title, location, starts_at, ends_at} when timed, or
--  {source_id, title, location, start_date, end_date} when all-day.
-- ---------------------------------------------------------------------

create or replace function public.replace_my_calendar(
  p_source        text,
  p_calendar_id   text,
  p_calendar_name text,
  p_events        jsonb
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  me uuid := auth.uid();
  n  integer;
begin
  if me is null then
    raise exception 'Not signed in';
  end if;

  delete from public.my_events m
   where m.owner_id = me
     and m.source = p_source
     and m.calendar_id = p_calendar_id
     and not exists (
       select 1 from jsonb_array_elements(coalesce(p_events, '[]')) x
        where x->>'source_id' = m.source_id
     );

  insert into public.my_events
    (owner_id, source, calendar_id, calendar_name, source_id, title, location,
     starts_at, ends_at, start_date, end_date, updated_at)
  select distinct on (x->>'source_id')
         me, p_source, p_calendar_id, p_calendar_name, x->>'source_id',
         nullif(btrim(x->>'title'), ''), nullif(btrim(x->>'location'), ''),
         (x->>'starts_at')::timestamptz, (x->>'ends_at')::timestamptz,
         (x->>'start_date')::date, (x->>'end_date')::date, now()
    from jsonb_array_elements(coalesce(p_events, '[]')) x
   where nullif(x->>'source_id', '') is not null
  on conflict (owner_id, source, calendar_id, source_id) do update
     set calendar_name = excluded.calendar_name,
         title         = excluded.title,
         location      = excluded.location,
         starts_at     = excluded.starts_at,
         ends_at       = excluded.ends_at,
         start_date    = excluded.start_date,
         end_date      = excluded.end_date,
         updated_at    = now();

  get diagnostics n = row_count;
  return n;
end;
$$;

-- Unticked calendars, or a whole source on disconnect (p_keep empty).
create or replace function public.forget_my_calendars(p_source text, p_keep text[])
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  n integer;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  delete from public.my_events
   where owner_id = auth.uid()
     and source = p_source
     and calendar_id <> all(coalesce(p_keep, '{}'));
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.replace_my_calendar(text, text, text, jsonb) from public;
revoke all on function public.forget_my_calendars(text, text[]) from public;
grant execute on function public.replace_my_calendar(text, text, text, jsonb) to authenticated;
grant execute on function public.forget_my_calendars(text, text[]) to authenticated;

-- ---------------------------------------------------------------------
--  Bridge: an older client still writing external_events keeps
--  my_events current, so reminders don't go quiet before it updates.
-- ---------------------------------------------------------------------

create or replace function private.bridge_external_event()
returns trigger
language plpgsql
security definer
set search_path = private, public
as $$
declare
  tz text;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    -- Gone only when no Orb still carries it.
    if not exists (
      select 1 from public.external_events e
       where e.owner_id = old.owner_id
         and e.calendar_source = old.calendar_source
         and e.calendar_name = old.calendar_name
         and e.source_id = old.source_id
         and e.id <> old.id
    ) then
      delete from public.my_events
       where owner_id = old.owner_id and source = old.calendar_source
         and calendar_id = old.calendar_name and source_id = old.source_id;
    end if;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select coalesce(np.time_zone, 'UTC') into tz
      from public.notification_prefs np where np.user_id = new.owner_id;
    tz := coalesce(tz, 'UTC');

    insert into public.my_events
      (owner_id, source, calendar_id, calendar_name, source_id, title, location,
       starts_at, ends_at, start_date, end_date, updated_at)
    values
      (new.owner_id, new.calendar_source, new.calendar_name, new.calendar_name,
       new.source_id, new.title, new.location,
       case when new.all_day then null else new.starts_at end,
       case when new.all_day then null else new.ends_at end,
       case when new.all_day then (new.starts_at at time zone tz)::date end,
       case when new.all_day
            then greatest((new.ends_at at time zone tz)::date,
                          (new.starts_at at time zone tz)::date) end,
       now())
    on conflict (owner_id, source, calendar_id, source_id) do update
       set title = excluded.title, location = excluded.location,
           starts_at = excluded.starts_at, ends_at = excluded.ends_at,
           start_date = excluded.start_date, end_date = excluded.end_date,
           updated_at = now();
  end if;

  return null;
end;
$$;

drop trigger if exists external_events_bridge on public.external_events;
create trigger external_events_bridge
  after insert or update or delete on public.external_events
  for each row execute function private.bridge_external_event();

-- ---------------------------------------------------------------------
--  push_tick: as in 022, with your events read from my_events. An
--  all-day event rings at 9 am your time on its first day (or the days
--  before, per your alerts). The same event from Google and Apple
--  counts once; one you made a plan from is left to the plan.
-- ---------------------------------------------------------------------

create or replace function private.push_tick()
returns void
language plpgsql
security definer
set search_path = private, public
as $$
declare
  q     private.push_queue;
  r     record;
  u     record;
  items jsonb;
begin
  -- Waiting news whose time has come.
  for q in
    delete from private.push_queue where deliver_at <= now() returning *
  loop
    if q.kind = 'idea' and q.n > 1 then
      perform private.push_send(q.recipient, q.space_id, 'ideas', null,
                                q.facts || jsonb_build_object('count', q.n));
    else
      perform private.push_send(q.recipient, q.space_id, q.kind, q.activity_id, q.facts);
    end if;
  end loop;

  -- Alerts due now. Two minutes of slack covers a late tick; the log
  -- keeps a slow one from sending twice.
  for r in
    select *
      from (
        select m.user_id, a.id, a.space_id, a.title, a.date_time, a.ends_at,
               a.all_day, a.location, mins,
               case
                 when a.all_day then
                   (((a.date_time at time zone 'UTC')::date - mins) + time '09:00')
                     at time zone np.time_zone
                 else a.date_time - make_interval(mins => mins)
               end as fire_at
          from public.activities a
          join public.spaces s on s.id = a.space_id and not coalesce(s.frozen, false)
          join public.space_members m on m.space_id = a.space_id
          left join public.notification_prefs np on np.user_id = m.user_id
          left join public.activity_alerts aa
                 on aa.user_id = m.user_id and aa.activity_id = a.id
                and aa.all_day = coalesce(a.all_day, false)
         cross join lateral unnest(
                 coalesce(
                   aa.alerts,
                   case when coalesce(a.all_day, false)
                        then coalesce(np.alert_all_day, '{0}')
                        else coalesce(np.alert_timed, '{30}') end
                 )
               ) as mins
         where a.date_time is not null
           and a.date_time between now() - interval '1 day' and now() + interval '9 days'
      ) due
     where due.fire_at > now() - interval '2 minutes'
       and due.fire_at <= now()
  loop
    insert into private.push_log (user_id, key)
    values (r.user_id, 'r:' || r.id || ':' || r.mins || ':' || extract(epoch from r.fire_at)::bigint)
    on conflict do nothing;
    if found then
      perform private.push_send(r.user_id, r.space_id, 'reminder', r.id,
        jsonb_build_object(
          'title',    r.title,
          'at',       r.date_time,
          'ends_at',  r.ends_at,
          'all_day',  coalesce(r.all_day, false),
          'location', nullif(btrim(r.location), '')
        ));
    end if;
  end loop;

  -- Your Google, Apple and Outlook events. All-day ones carry noon UTC
  -- on their day as `at`, the way all-day plans do.
  for r in
    select *
      from (
        select distinct on (ev.owner_id, lower(btrim(ev.title)), ev.at, mins)
               ev.owner_id as user_id, ev.title, ev.at, ev.ends_at, ev.all_day,
               ev.location, mins,
               case
                 when ev.all_day then
                   ((ev.start_date - mins) + time '09:00') at time zone ev.tz
                 else ev.at - make_interval(mins => mins)
               end as fire_at
          from (
            select e.owner_id, e.title, e.location, e.start_date,
                   (e.start_date is not null) as all_day,
                   coalesce(e.starts_at, (e.start_date + time '12:00') at time zone 'UTC') as at,
                   coalesce(e.ends_at, (e.end_date + time '12:00') at time zone 'UTC') as ends_at,
                   coalesce(np.time_zone, 'UTC') as tz,
                   np.alert_timed, np.alert_all_day
              from public.my_events e
              left join public.notification_prefs np on np.user_id = e.owner_id
             where nullif(btrim(e.title), '') is not null
               and (e.starts_at between now() - interval '1 day' and now() + interval '9 days'
                    or e.start_date between current_date - 1 and current_date + 9)
          ) ev
         cross join lateral unnest(
                 case when ev.all_day then coalesce(ev.alert_all_day, '{0}')
                      else coalesce(ev.alert_timed, '{30}') end
               ) as mins
         where not exists (
             select 1
               from public.activities a
               join public.space_members am on am.space_id = a.space_id and am.user_id = ev.owner_id
              where lower(btrim(a.title)) = lower(btrim(ev.title))
                and case when ev.all_day
                         then coalesce(a.all_day, false)
                              and (a.date_time at time zone 'UTC')::date = ev.start_date
                         else a.date_time = ev.at end
           )
         order by ev.owner_id, lower(btrim(ev.title)), ev.at, mins
      ) due
     where due.fire_at > now() - interval '2 minutes'
       and due.fire_at <= now()
  loop
    insert into private.push_log (user_id, key)
    values (r.user_id,
            'e:' || md5(lower(btrim(r.title)) || r.at::text) || ':' || r.mins
                 || ':' || extract(epoch from r.fire_at)::bigint)
    on conflict do nothing;
    if found then
      perform private.push_send(r.user_id, null, 'reminder', null,
        jsonb_build_object(
          'title',    r.title,
          'at',       r.at,
          'ends_at',  r.ends_at,
          'all_day',  r.all_day,
          'location', nullif(btrim(r.location), ''),
          'external', true
        ));
    end if;
  end loop;

  -- Morning summaries. Five minutes of slack; once a day each.
  for u in
    select np.user_id, np.time_zone, (now() at time zone np.time_zone) as local_ts
      from public.notification_prefs np
     where np.summary_minute is not null
       and np.time_zone is not null
       and (extract(hour from now() at time zone np.time_zone) * 60
            + extract(minute from now() at time zone np.time_zone))
           between np.summary_minute and np.summary_minute + 4
  loop
    insert into private.push_log (user_id, key)
    values (u.user_id, 's:' || u.local_ts::date)
    on conflict do nothing;
    continue when not found;

    -- Your plans and your own events, each once: timed ones first in
    -- order, then all-day, and nothing that's already over.
    select jsonb_agg(x order by (x->>'all_day')::boolean, (x->>'at')::timestamptz)
      into items
      from (
        select jsonb_build_object('title', a.title, 'at', a.date_time,
                                  'all_day', coalesce(a.all_day, false)) as x
          from public.activities a
          join public.spaces s on s.id = a.space_id and not coalesce(s.frozen, false)
          join public.space_members m on m.space_id = a.space_id and m.user_id = u.user_id
         where a.date_time is not null
           and case when coalesce(a.all_day, false)
                    then (a.date_time at time zone 'UTC')::date
                    else (a.date_time at time zone u.time_zone)::date end
               = u.local_ts::date
           and (coalesce(a.all_day, false) or coalesce(a.ends_at, a.date_time) > now())
        union
        select jsonb_build_object(
                 'title', e.title,
                 'at', coalesce(e.starts_at, (e.start_date + time '12:00') at time zone 'UTC'),
                 'all_day', e.start_date is not null)
          from public.my_events e
         where e.owner_id = u.user_id
           and nullif(btrim(e.title), '') is not null
           and (e.start_date = u.local_ts::date
                or ((e.starts_at at time zone u.time_zone)::date = u.local_ts::date
                    and coalesce(e.ends_at, e.starts_at) > now()))
      ) today;

    if items is not null then
      perform private.push_send(u.user_id, null, 'summary', null,
        jsonb_build_object('items', items, 'day', u.local_ts::date));
    end if;
  end loop;

  if extract(minute from now()) = 0 then
    delete from private.push_log where sent_at < now() - interval '30 days';
  end if;
end;
$$;

notify pgrst, 'reload schema';
