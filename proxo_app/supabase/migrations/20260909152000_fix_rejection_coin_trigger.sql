-- The legacy rejection trigger referenced a removed pa_coins relation.
-- Coins now live on pa_wallets; lock the owner wallet before the adjustment.
create or replace function public.handle_ad_rejection()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.status = 'rejected' and old.status is distinct from 'rejected' then
    perform public.pa_lock_wallet(new.user_id);
    update public.pa_wallets
       set coins_balance = greatest(0, coalesce(coins_balance, 0) - 50),
           updated_at = now()
     where user_id = new.user_id;
  end if;
  return new;
end
$function$;

revoke all on function public.handle_ad_rejection() from public, anon, authenticated;
grant execute on function public.handle_ad_rejection() to service_role;
