-- =====================================================================
--  013 — Explicit external event sharing for Orbs
--
--  Imported calendar events are 100% private to the owner by default.
--  A member can explicitly toggle `shared_with_space` so their partner
--  or group can see their availability context without making it a plan.
-- =====================================================================

alter table public.external_events
  add column if not exists shared_with_space boolean not null default false;

-- Update RLS so members can only read an external event if they own it
-- or if the owner explicitly shared it with the space.
drop policy if exists "members read external events" on public.external_events;
create policy "members read external events" on public.external_events
  for select using (
    public.is_space_member(space_id) and (
      owner_id = auth.uid() or shared_with_space = true
    )
  );

-- Function to toggle sharing for an external event atomically
create or replace function public.toggle_external_event_share(p_event_id uuid, p_shared boolean)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select owner_id into v_owner from public.external_events where id = p_event_id;
  if v_owner is null then
    raise exception 'Event not found';
  end if;
  if v_owner <> auth.uid() then
    raise exception 'Not authorized to change sharing for this event';
  end if;

  update public.external_events
     set shared_with_space = p_shared,
         updated_at = now()
   where id = p_event_id;

  return p_shared;
end;
$$;

revoke all on function public.toggle_external_event_share(uuid, boolean) from public;
grant execute on function public.toggle_external_event_share(uuid, boolean) to authenticated;
grant select, update (shared_with_space, updated_at) on public.external_events to authenticated;
