-- v57: the wallet editor in the panel saves the two wallet rules
-- (ex_wallets.recipient_format, ex_wallets.sender_phone_required). Routes and fees untouched.
do $patch$
declare
  v_fn constant regprocedure := 'public.ex_staff_save_wallet(uuid,jsonb,jsonb)'::regprocedure;
  v_def text := pg_get_functiondef(v_fn);
  v_upd_old constant text := E'badge=p_wallet->>''badge''\n   where id=p_wallet_id';
  v_upd_new constant text := E'badge=p_wallet->>''badge'',\n   recipient_format=coalesce(nullif(p_wallet->>''recipient_format'',''''),recipient_format),\n   sender_phone_required=coalesce((p_wallet->>''sender_phone_required'')::boolean,sender_phone_required)\n   where id=p_wallet_id';
  v_ins_cols_old constant text := 'allow_from,allow_receive,is_locked,badge,sort_order)';
  v_ins_cols_new constant text := 'allow_from,allow_receive,is_locked,badge,sort_order,recipient_format,sender_phone_required)';
  v_ins_vals_old constant text := '(select coalesce(max(sort_order),0)+1 from public.ex_wallets)) returning * into w;';
  v_ins_vals_new constant text := E'(select coalesce(max(sort_order),0)+1 from public.ex_wallets),\n   coalesce(nullif(p_wallet->>''recipient_format'',''''),''phone''),coalesce((p_wallet->>''sender_phone_required'')::boolean,false)) returning * into w;';
begin
  if position('recipient_format' in v_def) > 0 then return; end if;
  if position(v_upd_old in v_def) = 0 or position(v_ins_cols_old in v_def) = 0 or position(v_ins_vals_old in v_def) = 0 then
    raise exception 'ex_staff_save_wallet changed; wallet rules not added';
  end if;
  v_def := replace(replace(replace(v_def, v_upd_old, v_upd_new), v_ins_cols_old, v_ins_cols_new), v_ins_vals_old, v_ins_vals_new);
  execute v_def;
end $patch$;
