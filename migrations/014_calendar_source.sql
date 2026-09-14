-- =====================================================================
--  014 — Calendar source on imported overlays
--
--  Google / Apple / Outlook can all land in external_events. Refresh must
--  not wipe another source, and share flags must survive a re-import.
-- =====================================================================

alter table public.external_events
  add column if not exists calendar_source text not null default 'google';

do $$
begin
  alter table public.external_events
    add constraint external_events_calendar_source_check
    check (calendar_source in ('google', 'apple', 'outlook'));
exception
  when duplicate_object then null;
end $$;

alter table public.external_events
  drop constraint if exists external_events_space_id_owner_id_source_id_key;

create unique index if not exists external_events_source_uniq
  on public.external_events (space_id, owner_id, calendar_source, source_id);
