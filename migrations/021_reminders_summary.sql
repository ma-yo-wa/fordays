-- =====================================================================
--  021 — Reminders, the morning summary, and calmer sending
--
--  Reminders work the way Google and Apple Calendar do:
--    - Alerts are yours, not the plan's. Everyone in the Orb has their
--      own, and a plan with none of your own uses your defaults.
--    - Timed plans: minutes before (0 = at the time). Default 30, as Google.
--    - All-day plans: days before, at 9 am in your zone (0 = on the day).
--      Default on the day, as both do.
--    - Up to two alerts (Apple's Alert and Second alert).
--    - Moving the plan moves the alert; Someday or delete cancels it.
--      Nothing is stored per alert, so there is nothing to go stale:
--      every minute the tick works out what is due right now.
--
--  Morning summary: 8:00 am in your zone by default, only on days with
--  plans, across all your Orbs.
--
--  Also: moved back to Someday, removed, left; adds in a row grouped;
--  quiet hours 10 pm – 8 am for things other people did (alerts you set
--  still ring); mute an Orb.
-- =====================================================================

create extension if not exists pg_cron;

-- 1. Your settings -----------------------------------------------------

create table if not exists public.notification_prefs (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  time_zone      text,
  alert_timed    int[] not null default '{30}',
  alert_all_day  int[] not null default '{0}',
  summary_minute int default 480,          -- minutes after midnight; null = off
  quiet_hours    boolean not null default true,
  updated_at     timestamptz not null default now()
);

alter table public.notification_prefs enable row level security;

drop policy if exists "own prefs" on public.notification_prefs;
create policy "own prefs" on public.notification_prefs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Your alerts on one plan. all_day records which kind of plan they were
-- set for; if the plan changes kind, your defaults take over again.
create table if not exists public.activity_alerts (
  user_id     uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  all_day     boolean not null,
  alerts      int[] not null,
  updated_at  timestamptz not null default now(),
  primary key (user_id, activity_id)
);

alter table public.activity_alerts enable row level security;

drop policy if exists "own alerts" on public.activity_alerts;
create policy "own alerts" on public.activity_alerts
  for all
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.activities a
       where a.id = activity_id and public.is_space_member(a.space_id)
    )
  );

alter table public.space_members
  add column if not exists muted boolean not null default false;

create or replace function public.set_orb_muted(target_space uuid, mute boolean)
returns void
language sql
security definer
set search_path = public
as $$
  update public.space_members
     set muted = mute
   where space_id = target_space and user_id = auth.uid();
$$;

revoke execute on function public.set_orb_muted(uuid, boolean) from anon;
grant  execute on function public.set_orb_muted(uuid, boolean) to authenticated;

-- A zone the database can't read would break every tick, so it's checked
-- once here. The newest device's zone is the person's zone.
create or replace function private.valid_tz(tz text)
returns text
language plpgsql
stable
as $$
begin
  if tz is null or btrim(tz) = '' then return null; end if;
  perform now() at time zone tz;
  return tz;
exception when others then
  return null;
end;
$$;

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
declare
  tz text := private.valid_tz(device_tz);
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
     device_apns_env, tz, left(device_agent, 180), now())
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

  if tz is not null then
    insert into public.notification_prefs (user_id, time_zone)
    values (auth.uid(), tz)
    on conflict (user_id) do update set time_zone = excluded.time_zone;
  end if;
end;
$$;

-- Zones for people whose devices registered before this migration.
insert into public.notification_prefs (user_id, time_zone)
select distinct on (user_id) user_id, private.valid_tz(time_zone)
  from public.push_subscriptions
 where private.valid_tz(time_zone) is not null
 order by user_id, last_seen desc
on conflict (user_id) do update set time_zone = excluded.time_zone;

-- 2. Sending ------------------------------------------------------------

create table if not exists private.push_queue (
  id          bigserial primary key,
  recipient   uuid not null,
  space_id    uuid,
  kind        text not null,
  activity_id uuid,
  facts       jsonb not null,
  deliver_at  timestamptz not null,
  batch_key   text unique,
  n           int not null default 1
);
create index if not exists push_queue_due_idx on private.push_queue (deliver_at);

-- What has already gone out, so a tick never sends the same alert twice.
create table if not exists private.push_log (
  user_id uuid not null,
  key     text not null,
  sent_at timestamptz not null default now(),
  primary key (user_id, key)
);

-- Straight to push-fan-out. Adds the Orb's name when the person is in
-- more than one shared Orb.
create or replace function private.push_send(
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
  fn_url      text := private.cfg('push_fn_url');
  fn_key      text := private.cfg('push_fn_key');
  orb_name    text;
  shared_orbs int;
begin
  if recipient is null or fn_url is null or fn_key is null then
    return;
  end if;

  if space is not null then
    select count(*) into shared_orbs
      from public.space_members m
      join public.spaces s on s.id = m.space_id
     where m.user_id = recipient
       and not coalesce(s.frozen, false)
       and (select count(*) from public.space_members o where o.space_id = s.id) > 1;

    if shared_orbs > 1 then
      select nullif(btrim(name), '') into orb_name from public.spaces where id = space;
    end if;
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
      raise warning 'push_send failed: %', sqlerrm;
  end;
end;
$$;

-- Something another person did. Muted Orbs stay quiet; adds wait two
-- minutes so a run of them becomes one; overnight waits for 8 am.
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
set search_path = private, public
as $$
declare
  prefs    public.notification_prefs;
  deliver  timestamptz := now();
  key      text;
  local_ts timestamp;
begin
  if recipient is null then
    return;
  end if;

  if exists (
    select 1 from public.space_members
     where space_id = space and user_id = recipient and muted
  ) then
    return;
  end if;

  select * into prefs from public.notification_prefs where user_id = recipient;

  if kind = 'idea' then
    deliver := now() + interval '2 minutes';
    key := 'idea:' || recipient || ':' || space || ':' || coalesce(facts->>'actor_id', '');
  elsif activity is not null then
    key := 'act:' || recipient || ':' || activity;
  end if;

  if coalesce(prefs.quiet_hours, true) and prefs.time_zone is not null then
    local_ts := deliver at time zone prefs.time_zone;
    if local_ts::time >= time '22:00' or local_ts::time < time '08:00' then
      deliver := ((case when local_ts::time >= time '22:00'
                        then local_ts::date + 1 else local_ts::date end)
                  + time '08:00') at time zone prefs.time_zone;
    end if;
  end if;

  if deliver <= now() then
    -- Anything still waiting about this plan is older news.
    if key is not null then
      delete from private.push_queue where batch_key = key;
    end if;
    perform private.push_send(recipient, space, kind, activity, facts);
    return;
  end if;

  insert into private.push_queue
    (recipient, space_id, kind, activity_id, facts, deliver_at, batch_key)
  values
    (recipient, space, kind, activity, facts, deliver, key)
  on conflict (batch_key) do update
    set kind       = excluded.kind,
        activity_id = excluded.activity_id,
        facts      = excluded.facts,
        n          = private.push_queue.n
                     + case when excluded.kind = 'idea' then 1 else 0 end,
        deliver_at = greatest(private.push_queue.deliver_at, excluded.deliver_at);
end;
$$;

-- 3. What other people do --------------------------------------------

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
  elsif tg_op = 'UPDATE' and old.date_time is not null and new.date_time is null then
    kind := 'unscheduled';
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
    'actor',    private.first_name(actor),
    'actor_id', actor,
    'title',    new.title,
    'note',     case
                  when kind = 'suggested' then nullif(btrim(new.suggested_note), '')
                  when kind in ('idea', 'notes') then nullif(btrim(new.description), '')
                end,
    'at',       case when kind = 'suggested' then new.suggested_date_time else new.date_time end,
    'all_day',  case when kind = 'suggested' then coalesce(new.suggested_all_day, false)
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

create or replace function public.notify_activity_removed()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  actor     uuid := auth.uid();
  recipient uuid;
  facts     jsonb;
begin
  -- No person behind it (an Orb being deleted, a cleanup): say nothing.
  if actor is null then
    return old;
  end if;
  if not exists (select 1 from public.spaces where id = old.space_id and not frozen) then
    return old;
  end if;

  facts := jsonb_build_object(
    'actor',    private.first_name(actor),
    'actor_id', actor,
    'title',    old.title
  );

  -- Waiting news about a plan that's gone is no news.
  delete from private.push_queue where activity_id = old.id;

  for recipient in
    select m.user_id
      from public.space_members m
     where m.space_id = old.space_id
       and m.user_id <> actor
  loop
    perform private.enqueue_push_event(recipient, old.space_id, 'deleted', null, facts);
  end loop;

  return old;
end;
$$;

drop trigger if exists activities_notify_removed on public.activities;
create trigger activities_notify_removed
  after delete on public.activities
  for each row execute function public.notify_activity_removed();

create or replace function public.notify_member_left()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  recipient uuid;
  facts     jsonb;
begin
  -- Only someone leaving on their own. The last one out freezes the Orb
  -- first, so nobody is left to tell.
  if auth.uid() is distinct from old.user_id then
    return old;
  end if;
  if not exists (select 1 from public.spaces where id = old.space_id and not frozen) then
    return old;
  end if;

  facts := jsonb_build_object(
    'actor', private.first_name(old.user_id),
    'orb_name', (select nullif(btrim(name), '') from public.spaces where id = old.space_id)
  );

  for recipient in
    select m.user_id
      from public.space_members m
     where m.space_id = old.space_id
       and m.user_id <> old.user_id
  loop
    perform private.enqueue_push_event(recipient, old.space_id, 'left', null, facts);
  end loop;

  return old;
end;
$$;

drop trigger if exists space_members_notify_left on public.space_members;
create trigger space_members_notify_left
  after delete on public.space_members
  for each row execute function public.notify_member_left();

-- 4. Every minute ------------------------------------------------------

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

    select jsonb_agg(
             jsonb_build_object('title', a.title, 'at', a.date_time, 'all_day', coalesce(a.all_day, false))
             order by coalesce(a.all_day, false) desc, a.date_time
           )
      into items
      from public.activities a
      join public.spaces s on s.id = a.space_id and not coalesce(s.frozen, false)
      join public.space_members m on m.space_id = a.space_id and m.user_id = u.user_id
     where a.date_time is not null
       and case when coalesce(a.all_day, false)
                then (a.date_time at time zone 'UTC')::date
                else (a.date_time at time zone u.time_zone)::date end
           = u.local_ts::date;

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

select cron.schedule('fordays-push-tick', '* * * * *', 'select private.push_tick()');

notify pgrst, 'reload schema';
