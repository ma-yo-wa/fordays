-- =====================================================================
--  015 — Remove UTC time string from push notification bodies
--
--  The PostgreSQL server runs in UTC. Formatting timestamps via
--  `to_char(... at time zone 'UTC', 'HH12:MI AM')` bakes UTC clock
--  times into push notifications (e.g. 9:00 PM EST appears as 1:00 AM UTC).
--  Keep push notifications clean and human without raw UTC times.
-- =====================================================================

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
    if old.date_time is null and new.date_time is not null then
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
