-- Ordinary admins may read account information, but cannot mutate other accounts.
-- Super-admin account actions continue through the protected server/RPC paths.

revoke update (is_admin,is_banned) on public.ex_profiles from authenticated;

drop policy if exists "ex_profiles_update" on public.ex_profiles;
create policy "ex_profiles_update"
on public.ex_profiles
for update
to authenticated
using (
  (select auth.uid()) = id
  or (select public.ex_is_super_admin())
)
with check (
  (select auth.uid()) = id
  or (select public.ex_is_super_admin())
);
