-- Run with an administrative test connection. All fixtures and purchases are
-- rolled back inside a PL/pgSQL subtransaction. No real account is modified.
do $tests$
declare
  u uuid := gen_random_uuid(); other_u uuid := gen_random_uuid();
  submission uuid := gen_random_uuid(); card uuid := gen_random_uuid();
  promo uuid := gen_random_uuid(); promo_code text := 'TEST'||upper(substr(gen_random_uuid()::text,1,8));
  d jsonb; q jsonb; r jsonb; replay jsonb; before_balance numeric; after_balance numeric;
  checks jsonb := '[]'::jsonb;
begin
  begin
    insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
      values(u,'authenticated','authenticated','rollback-'||u||'@example.invalid','{}','{"full_name":"Rollback test"}'),
            (other_u,'authenticated','authenticated','rollback-'||other_u||'@example.invalid','{}','{"full_name":"Rollback test"}');
    insert into public.pa_wallets(user_id,balance) values(u,1000),(other_u,1000)
      on conflict(user_id) do update set balance=excluded.balance;
    insert into public.proxolink_cards(id,user_id,name) values(card,u,'Rollback contact page');
    insert into public.promo_codes(id,code,discount_type,discount_value,max_uses,expires_at,created_by,restricted_to_user_id)
      values(promo,promo_code,'fixed',2000,2,now()+interval '1 day',u::text,u);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);
    d := jsonb_build_object('title','Rollback ABC-123','goal','messages','category','cosmetics_beauty',
      'age_groups','["18-24","25-34"]'::jsonb,'gender','female','location','kurdistan','device_type','iphone',
      'customer_note','تێبینی ABC-123','daily_budget',10,'days',2,
      'video_link','https://www.tiktok.com/@proxo/video/1234567890123456789','video_code','ABC-123',
      'asset_id',card,'start_date',to_char(timezone('Asia/Baghdad',now())+interval '1 day','YYYY-MM-DD'),
      'start_time','12:00','payment_method','app_balance','payment_transaction_id',null);

    q := public.pa_preview_ad(d,promo,promo_code);
    if q->>'ok'<>'true' or round((q->>'promo_discount_usd')::numeric*(q->>'rate')::numeric)<>2000
      then raise exception 'fixed coupon quote failed: %',q; end if;
    checks := checks||'"server_quote_fixed_coupon"'::jsonb;
    select balance into before_balance from public.pa_wallets where user_id=u;
    r := public.pa_submit_ad(submission,d,(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,promo,promo_code);
    if r->>'ok'<>'true' then raise exception 'purchase failed: %',r; end if;
    select balance into after_balance from public.pa_wallets where user_id=u;
    if before_balance-after_balance<>(q->>'cost_usd')::numeric then raise exception 'incorrect debit'; end if;
    if (select count(*) from public.pa_transactions where user_id=u and type='ad_payment')<>1
      then raise exception 'ledger count failed'; end if;
    if not exists(select 1 from public.pa_transactions where user_id=u and ad_id=(r->>'ad_id')::uuid
      and amount=(q->>'cost_usd')::numeric and balance_after=after_balance)
      then raise exception 'ledger values failed'; end if;
    if not exists(select 1 from public.pa_ads where id=(r->>'ad_id')::uuid and user_id=u
      and asset_id=card and goal='messages' and daily_budget=10 and days=2 and gender='female'
      and location='kurdistan' and device_type='iphone' and category='cosmetics_beauty'
      and status='scheduled' and charged_price_iqd=(q->>'amount_iqd')::numeric)
      then raise exception 'ad fields or price snapshot failed'; end if;
    checks := checks||'["atomic_ad_wallet_ledger","stored_targeting_schedule_and_contact","charged_price_snapshot"]'::jsonb;

    replay := public.pa_submit_ad(submission,d,(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,promo,promo_code);
    if replay<>r or (select balance from public.pa_wallets where user_id=u)<>after_balance
      or (select count(*) from public.pa_ads where user_id=u)<>1
      or (select used_count from public.promo_codes where id=promo)<>1
      then raise exception 'idempotent replay charged twice'; end if;
    if public.pa_ad_submission_status(submission)<>r then raise exception 'recovery lookup failed'; end if;
    checks := checks||'["same_key_replay_exactly_once","coupon_consumed_once","interrupted_response_recovery"]'::jsonb;

    replay := public.pa_submit_ad(submission,d||'{"title":"Changed"}',(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,promo,promo_code);
    if replay->>'code'<>'IDEMPOTENCY_CONFLICT' then raise exception 'conflicting replay accepted'; end if;
    checks := checks||'"changed_payload_same_key_rejected"'::jsonb;

    q := public.pa_preview_ad(d,null,null);
    r := public.pa_submit_ad(gen_random_uuid(),d,0,0,null,null);
    if r->>'code'<>'PRICE_CHANGED' then raise exception 'tampered quote accepted: %',r; end if;
    checks := checks||'"tampered_or_stale_confirmation_price_rejected"'::jsonb;
    update public.pa_wallets set balance=0 where user_id=u;
    r := public.pa_submit_ad(gen_random_uuid(),d,(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,null,null);
    if r->>'code'<>'INSUFFICIENT_FUNDS' or (select count(*) from public.pa_ads where user_id=u)<>1
      or (select count(*) from public.pa_transactions where user_id=u and type='ad_payment')<>1
      then raise exception 'insufficient funds created partial purchase'; end if;
    checks := checks||'"insufficient_funds_no_partial_operation"'::jsonb;
    update public.pa_wallets set balance=1000 where user_id=u;

    r := public.pa_submit_ad(gen_random_uuid(),d||'{"daily_budget":null}',10,18000,null,null);
    if r->>'code'<>'INVALID_INPUT' then raise exception 'null numeric input accepted'; end if;
    r := public.pa_submit_ad(gen_random_uuid(),d||'{"age_groups":[]}',(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,null,null);
    if r->>'code'<>'INVALID_AGE_GROUP' then raise exception 'empty ages accepted'; end if;
    r := public.pa_submit_ad(gen_random_uuid(),d||'{"asset_id":null}',(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,null,null);
    if r->>'code'<>'INVALID_ASSET' then raise exception 'missing contact accepted'; end if;
    r := public.pa_submit_ad(gen_random_uuid(),d||'{"start_date":"2000-01-01"}',(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,null,null);
    if r->>'code'<>'INVALID_SCHEDULE' then raise exception 'past schedule accepted'; end if;
    checks := checks||'["null_budget_rejected","empty_ages_rejected","messages_requires_contact","past_schedule_rejected"]'::jsonb;

    q := public.pa_preview_ad(d,promo,promo_code);
    if q->>'code'<>'INVALID_PROMO' then raise exception 'used coupon accepted'; end if;
    update public.promo_codes set used_count=0,expires_at=now()-interval '1 second' where id=promo;
    q := public.pa_preview_ad(d,promo,promo_code);
    if q->>'code'<>'INVALID_PROMO' then raise exception 'expired coupon accepted'; end if;
    checks := checks||'["used_coupon_rejected","expired_coupon_rejected"]'::jsonb;

    perform set_config('request.jwt.claims',jsonb_build_object('sub',other_u,'role','authenticated')::text,true);
    if public.pa_ad_submission_status(submission)->>'code'<>'NOT_FOUND' then raise exception 'cross-user receipt leak'; end if;
    q := public.pa_preview_ad(d,null,null);
    r := public.pa_submit_ad(gen_random_uuid(),d,(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,null,null);
    if r->>'code'<>'INVALID_ASSET' then raise exception 'foreign contact accepted'; end if;
    checks := checks||'["own_submission_only","foreign_contact_rejected"]'::jsonb;

    d := d||'{"goal":"views","asset_id":null,"start_immediately":true,"start_date":"2000-01-01"}'::jsonb;
    q := public.pa_preview_ad(d,null,null);
    r := public.pa_submit_ad(gen_random_uuid(),d,(q->>'cost_usd')::numeric,(q->>'amount_iqd')::bigint,null,null);
    if r->>'ok'<>'true' or not exists(select 1 from public.pa_ads where id=(r->>'ad_id')::uuid
      and user_id=other_u and asset_id is null and status='pending'
      and start_date+start_time>timezone('Asia/Baghdad',now())) then raise exception 'immediate views purchase failed'; end if;
    checks := checks||'["views_without_contact","immediate_start_uses_server_clock"]'::jsonb;

    perform set_config('request.jwt.claims','{}',true);
    if public.pa_preview_ad(d,null,null)->>'code'<>'NOT_AUTHENTICATED'
      or public.pa_ad_submission_status(submission)->>'code'<>'NOT_AUTHENTICATED'
      or public.pa_submit_ad(gen_random_uuid(),d,10,18000,null,null)->>'code'<>'NOT_AUTHENTICATED'
      then raise exception 'unauthenticated purchase allowed'; end if;
    checks := checks||'"authentication_required"'::jsonb;
    raise exception 'ROLLBACK_TEST_FIXTURES';
  exception when raise_exception then
    if sqlerrm<>'ROLLBACK_TEST_FIXTURES' then raise; end if;
  end;
  if exists(select 1 from auth.users where id in(u,other_u))
     or exists(select 1 from public.pa_ads where user_id in(u,other_u))
     or exists(select 1 from public.pa_transactions where user_id in(u,other_u))
     or exists(select 1 from proxo_private.ad_submissions where user_id in(u,other_u))
     then raise exception 'test fixtures escaped rollback'; end if;
  checks := checks||'"all_test_users_ads_wallets_transactions_and_retry_receipts_rolled_back"'::jsonb;
  perform set_config('proxo.test_results',checks::text,true);
end $tests$;
select current_setting('proxo.test_results')::jsonb as passed_checks;
