-- Proxo reward policy: all active offers expire seven days after issuance.
-- Existing open-ended or longer-lived offers are brought into the same policy.
update public.ex_user_rewards
set valid_until = created_at + interval '7 days',
    updated_at = now()
where active
  and (valid_until is null or valid_until > created_at + interval '7 days');

comment on column public.ex_user_rewards.valid_until is
  'Reward expiry; Proxo active offers are limited to seven days from issuance.';
