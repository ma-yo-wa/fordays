-- =====================================================================
--  018 — add from_someday column to activities
--  Only plans that originated from Someday or have a cover/photo
--  qualify as memories.
-- =====================================================================

alter table public.activities
  add column if not exists from_someday boolean not null default false;

-- Backfill: any activity with null date_time is in Someday;
-- any activity that has history of being scheduled/unscheduled from Someday.
update public.activities
  set from_someday = true
  where date_time is null
     or id in (
       select activity_id
       from public.audit_logs
       where action_type in ('scheduled', 'unscheduled')
     );

-- Ensure updating from Someday automatically sets from_someday
create or replace function public.set_activity_from_someday()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.date_time is null then
    new.from_someday := true;
  elsif old is not null and old.date_time is null and new.date_time is not null then
    new.from_someday := true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_activity_from_someday on public.activities;
create trigger trg_set_activity_from_someday
  before insert or update on public.activities
  for each row execute function public.set_activity_from_someday();

notify pgrst, 'reload schema';
