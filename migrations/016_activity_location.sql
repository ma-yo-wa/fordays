-- =====================================================================
--  016 — add location column to activities
-- =====================================================================

alter table public.activities
  add column if not exists location text;

-- Record location changes in the audit log when edited
create or replace function public.log_activity_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor uuid := coalesce(auth.uid(), new.created_by);
begin
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
      to_char(new.date_time, 'Mon DD, YYYY at HH12:MI AM'));
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
          to_char(new.date_time, 'Mon DD, YYYY at HH12:MI AM')
        else
          to_char(new.date_time, 'Mon DD, YYYY at HH12:MI AM')
          || ' to '
          || to_char(new.ends_at, 'Mon DD, YYYY at HH12:MI AM')
      end);
  end if;

  if old.image_url is distinct from new.image_url then
    insert into public.audit_logs (activity_id, space_id, user_id, action_type, details)
    values (new.id, new.space_id, actor, 'edited', 'changed the cover');
  end if;

  -- Unscheduling takes the span with it, so a bucket-list item can never
  -- keep a stale end date.
  if new.date_time is null then
    new.ends_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$$;
