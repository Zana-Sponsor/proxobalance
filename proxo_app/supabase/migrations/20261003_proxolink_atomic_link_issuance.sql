-- Run only after 20261003_proxolink_private_staging.sql.
-- Token issuance is atomic and callable ONLY with the trusted service role.
create or replace function public.proxolink_issue_ad_link(
  p_ad_id uuid,
  p_owner_user_id uuid,
  p_public_token text
)
returns table (
  link_id uuid, link_ad_id uuid, link_card_id uuid,
  link_public_token text, link_version integer
)
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_ad public.pa_ads%rowtype;
  v_card public.proxolink_cards%rowtype;
  v_current public.pa_ad_contact_links%rowtype;
  v_new public.pa_ad_contact_links%rowtype;
  v_version integer;
begin
  if p_public_token is null
    or p_public_token !~ '^[A-Za-z0-9_-]{20,128}$'
  then
    raise exception 'invalid_tracking_token';
  end if;
  -- Lock the exact ad so two concurrent requests cannot issue two current
  -- links. The caller must have been verified by Proxo Auth on the server.
  select * into v_ad from public.pa_ads
  where id=p_ad_id and user_id=p_owner_user_id for update;
  if not found or v_ad.asset_id is null then
    raise exception 'ad_not_found_or_not_owned';
  end if;
  select * into v_card from public.proxolink_cards
  where id=v_ad.asset_id and user_id=p_owner_user_id
    and status='active' and publish_status='ready';
  if not found then
    raise exception 'card_not_available';
  end if;
  select * into v_current from public.pa_ad_contact_links
  where ad_id=p_ad_id and is_current=true for update;
  if found and v_current.card_id=v_card.id
    and v_current.status='active' then
    return query select v_current.id,v_current.ad_id,v_current.card_id,
      v_current.public_token,v_current.version;
    return;
  end if;
  select coalesce(max(version),0)+1 into v_version
  from public.pa_ad_contact_links where ad_id=p_ad_id;
  if v_current.id is not null then
    update public.pa_ad_contact_links
    set is_current=false,status='inactive',deactivated_at=now()
    where id=v_current.id;
  end if;
  insert into public.pa_ad_contact_links(
    ad_id,card_id,owner_user_id,public_token,version
  ) values(
    v_ad.id,v_card.id,p_owner_user_id,p_public_token,v_version
  ) returning * into v_new;
  return query select v_new.id,v_new.ad_id,v_new.card_id,
    v_new.public_token,v_new.version;
end
$$;
revoke all on function public.proxolink_issue_ad_link(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.proxolink_issue_ad_link(uuid,uuid,text)
  to service_role;
