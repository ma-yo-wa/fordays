-- 011 — Soft delete when last member leaves
--
-- Keep data recoverable even when the last person deletes an Orb.
-- Behavior:
-- - If others remain: unchanged (they keep the live Orb; leaver gets a frozen copy).
-- - If no one else remains: do not hard-delete the live Orb row. Freeze it and
--   remove membership, while returning a frozen copy for the leaver.

create or replace function public.leave_space(sid uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  others int;
  copy_id uuid;
  next_admin uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if not exists (
    select 1 from public.space_members
     where space_id = sid and user_id = auth.uid()
  ) then
    raise exception 'You are not in that space';
  end if;

  select count(*) into others
    from public.space_members
   where space_id = sid and user_id <> auth.uid();

  -- Last member leaving: keep source as soft-deleted (frozen), and hand the
  -- person a frozen copy to look back at.
  if others = 0 then
    copy_id := public.snapshot_space_for(sid, auth.uid());

    update public.spaces
       set frozen = true
     where id = sid;

    delete from public.space_members
     where space_id = sid and user_id = auth.uid();

    perform public.sync_space_partner_columns(sid);
    return copy_id;
  end if;

  copy_id := public.snapshot_space_for(sid, auth.uid());

  delete from public.space_members
   where space_id = sid and user_id = auth.uid();

  if not exists (
    select 1 from public.space_members
     where space_id = sid and role = 'admin'
  ) then
    select user_id into next_admin
      from public.space_members
     where space_id = sid
     order by joined_at
     limit 1;
    if next_admin is not null then
      update public.space_members
         set role = 'admin'
       where space_id = sid and user_id = next_admin;
    end if;
  end if;

  perform public.sync_space_partner_columns(sid);
  return copy_id;
end;
$$;

revoke all on function public.leave_space(uuid) from public;
grant execute on function public.leave_space(uuid) to authenticated;
