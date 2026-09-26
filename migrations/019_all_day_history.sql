-- =====================================================================
--  019 — All-day plans log a date, not a time; date lines get a verb
--  All-day plans are stored at noon UTC, so history read "Sep 26, 2026
--  at 12:00 PM" for a plan with no time at all. Both clients also hide a
--  noon-UTC time on all-day plans, for entries written before this.
-- =====================================================================

-- "Sep 26, 2026" for all-day; "Sep 26, 2026 at 03:00 PM" (UTC) otherwise.
-- The clients turn the timed form into local time.
create or replace function public.audit_when(ts timestamptz, all_day boolean)
returns text
language sql
immutable
as $$
  select case
    when all_day then to_char(ts at time zone 'UTC', 'Mon FMDD, YYYY')
    else to_char(ts at time zone 'UTC', 'Mon DD, YYYY at HH12:MI AM')
  end
$$;

create or replace function public.log_activity_insert()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
  values (new.id, new.space_id, new.created_by,
          'created',
          case when new.date_time is null
               then 'added the idea "' || new.title || '"'
               else 'created the plan "' || new.title || '"' end);

  -- Born with a date? That's also a scheduling event.
  if new.date_time is not null then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, new.created_by, 'scheduled',
            'set it for ' || public.audit_when(new.date_time, new.all_day));
  end if;

  return new;
end;
$$;

-- Same as 017, with dates written through audit_when, and the verbs
-- back ("set it for", "moved it to"): 016/017 logged a bare date, so the
-- line read "Mayowa Sep 27, 2026".
create or replace function public.log_activity_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor uuid := coalesce(auth.uid(), new.created_by);
begin
  if old.space_id is distinct from new.space_id then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'created',
      case when new.date_time is not null then 'brought this plan into the Orb'
           else 'brought this into Someday'
      end);
  end if;

  if old.title is distinct from new.title then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'edited',
      'renamed to ' || new.title);
  end if;

  if old.description is distinct from new.description then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'edited',
      case when new.description is null or new.description = '' then 'cleared the note'
           else 'updated the note'
      end);
  end if;

  if old.location is distinct from new.location then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'edited',
      case when new.location is null or new.location = '' then 'removed location'
           else 'set location to ' || new.location
      end);
  end if;

  if old.date_time is null and new.date_time is not null then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'scheduled',
      'set it for ' || public.audit_when(new.date_time, new.all_day));
  elsif old.date_time is not null and new.date_time is null then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'unscheduled',
      'moved back to the bucket list');
  elsif old.date_time is distinct from new.date_time
        or old.ends_at is distinct from new.ends_at then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'rescheduled',
      case
        when new.ends_at is null then
          'moved it to ' || public.audit_when(new.date_time, new.all_day)
        else
          'moved it to ' || public.audit_when(new.date_time, new.all_day)
          || ' – '
          || public.audit_when(new.ends_at, new.all_day)
      end);
  end if;

  if old.image_url is distinct from new.image_url then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'edited', 'changed the cover');
  end if;

  if new.date_time is null then
    new.ends_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

notify pgrst, 'reload schema';
