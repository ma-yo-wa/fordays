-- =====================================================================
--  017 — Handle moving activities between Orbs (Audit logs & Push)
-- =====================================================================

-- 1. Record an audit log entry in the target space when an item is moved
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

  if new.date_time is null then
    new.ends_at := null;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

-- 2. Notify other members in the new space when an item is moved in
create or replace function private.notify_activity_change()
returns trigger
language plpgsql
security definer
as $$
declare
  actor      uuid := coalesce(auth.uid(), new.created_by);
  actor_name text;
  kind       text;
  title      text;
  body       text;
  recipient  uuid;
begin
  if tg_op = 'INSERT' then
    if new.date_time is not null then
      kind := 'scheduled';
    else
      kind := 'idea';
    end if;
  elsif tg_op = 'UPDATE' then
    if old.space_id is distinct from new.space_id then
      if new.date_time is not null then
        kind := 'scheduled';
      else
        kind := 'idea';
      end if;
    elsif old.date_time is null and new.date_time is not null then
      kind := 'scheduled';
    elsif old.suggested_date_time is null and new.suggested_date_time is not null then
      kind := 'suggested';
    elsif old.suggested_date_time is not null and new.date_time is not null
          and new.date_time = old.suggested_date_time
          and new.suggested_date_time is null then
      kind := 'suggestion_accepted';
    elsif old.description is distinct from new.description
          and coalesce(btrim(new.description), '') <> '' then
      kind := 'notes';
    else
      return new;
    end if;
  else
    return new;
  end if;

  select p.display_name into actor_name
    from public.profiles p
   where p.id = actor;
  actor_name := coalesce(actor_name, 'Someone');

  if kind = 'suggested' then
    title := '💬 ' || actor_name || ' suggested a date for ' || new.title;
    body  := case
               when coalesce(btrim(new.suggested_note), '') <> '' then left(new.suggested_note, 120)
               else 'Open Fordays to review the suggestion'
             end;
  elsif kind = 'suggestion_accepted' then
    title := '✅ ' || actor_name || ' accepted your date for ' || new.title;
    body  := 'It’s locked in on your calendar!';
  elsif kind = 'idea' then
    title := '💡 ' || actor_name || ' added “' || new.title || '” to the bucket';
    body  := case
               when coalesce(btrim(new.description), '') <> '' then left(new.description, 120)
               else 'Open Fordays when you’re free'
             end;
  elsif kind = 'scheduled' then
    title := '📅 ' || actor_name || ' locked in ' || new.title || '!';
    body  := 'It’s on your calendar — tap to view';
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

notify pgrst, 'reload schema';
