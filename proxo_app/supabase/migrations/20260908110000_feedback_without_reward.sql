-- Completed-ad feedback is a product-quality signal, not a paid action.
-- Keep the existing pa_ads feedback columns and 1..5 rating scale, but remove
-- all voucher, wallet, transaction, notification and reward side effects.

create or replace function public.submit_ad_feedback(
  p_ad_id uuid,
  p_rating smallint,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_status text;
  v_existing_rating smallint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_rating');
  end if;

  select status, feedback_rating
  into v_status, v_existing_rating
  from public.pa_ads
  where id = p_ad_id
    and user_id = v_uid
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'ad_not_found');
  end if;

  if v_status not in ('completed', 'done') then
    return jsonb_build_object('ok', false, 'reason', 'ad_not_completed');
  end if;

  if v_existing_rating is not null then
    return jsonb_build_object('ok', false, 'reason', 'already_rated');
  end if;

  update public.pa_ads
  set feedback_rating = p_rating,
      feedback_comment = nullif(trim(coalesce(p_comment, '')), ''),
      feedback_at = now()
  where id = p_ad_id
    and user_id = v_uid;

  return jsonb_build_object(
    'ok', true,
    'rating', p_rating
  );
end;
$function$;

-- SECURITY DEFINER functions are executable by PUBLIC by default. The
-- function validates ownership internally, and its API surface is also kept
-- to signed-in clients only.
revoke all on function public.submit_ad_feedback(uuid, smallint, text)
  from public, anon;
grant execute on function public.submit_ad_feedback(uuid, smallint, text)
  to authenticated, service_role;

comment on function public.submit_ad_feedback(uuid, smallint, text) is
  'Stores one 1..5 rating for an owned completed ad. No reward is issued.';
