-- =====================================================================
--  022 — Your Google and Apple events remind you too
--
--  An imported event is a plan like any other to the person who imported
--  it, so it rings with their default alerts (30 minutes before, or 9 am
--  on the day for all-day) and shows in their morning summary. Only the
--  owner hears about it. Counted once however many Orbs or calendars it
--  came in through, and skipped when they already made a plan from it.
--
--  The summary also leaves out anything already over, and lists timed
--  plans first so the banner leads with what's next.
-- =====================================================================

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

  -- Your Google and Apple events remind you too, with your defaults, so
  -- Fordays can be the one place your day rings from. An event imported
  -- into several Orbs, or from both Google and Apple, counts once; one you
  -- already made a plan from is left to the plan.
  for r in
    select *
      from (
        select distinct on (e.owner_id, lower(btrim(e.title)), e.starts_at, mins)
               e.owner_id as user_id, e.title, e.starts_at, e.ends_at, e.all_day,
               e.location, mins,
               case
                 when e.all_day then
                   (((e.starts_at at time zone coalesce(np.time_zone, 'UTC'))::date - mins)
                     + time '09:00') at time zone coalesce(np.time_zone, 'UTC')
                 else e.starts_at - make_interval(mins => mins)
               end as fire_at
          from public.external_events e
          join public.spaces s on s.id = e.space_id and not coalesce(s.frozen, false)
          left join public.notification_prefs np on np.user_id = e.owner_id
         cross join lateral unnest(
                 case when e.all_day then coalesce(np.alert_all_day, '{0}')
                      else coalesce(np.alert_timed, '{30}') end
               ) as mins
         where e.starts_at between now() - interval '1 day' and now() + interval '9 days'
           and nullif(btrim(e.title), '') is not null
           and not exists (
             select 1
               from public.activities a
               join public.space_members am on am.space_id = a.space_id and am.user_id = e.owner_id
              where a.date_time = e.starts_at
                and lower(btrim(a.title)) = lower(btrim(e.title))
           )
         order by e.owner_id, lower(btrim(e.title)), e.starts_at, mins
      ) due
     where due.fire_at > now() - interval '2 minutes'
       and due.fire_at <= now()
  loop
    insert into private.push_log (user_id, key)
    values (r.user_id,
            'e:' || md5(lower(btrim(r.title)) || r.starts_at::text) || ':' || r.mins
                 || ':' || extract(epoch from r.fire_at)::bigint)
    on conflict do nothing;
    if found then
      perform private.push_send(r.user_id, null, 'reminder', null,
        jsonb_build_object(
          'title',    r.title,
          'at',       r.starts_at,
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

    -- Your plans and your Google and Apple events, each once: timed ones
    -- first in order, then all-day, and nothing that's already over.
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
        select jsonb_build_object('title', e.title, 'at', e.starts_at, 'all_day', e.all_day)
          from public.external_events e
          join public.spaces s on s.id = e.space_id and not coalesce(s.frozen, false)
         where e.owner_id = u.user_id
           and nullif(btrim(e.title), '') is not null
           and (e.starts_at at time zone u.time_zone)::date = u.local_ts::date
           and (e.all_day or coalesce(e.ends_at, e.starts_at) > now())
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

