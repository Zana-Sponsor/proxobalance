-- Remove the pre-selfie overload: both versions have defaulted trailing arguments,
-- so PostgREST cannot resolve ex_kyc_submit RPC calls (PGRST203).
-- Keep the current implementation that includes p_selfie_path.
drop function if exists public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date);
notify pgrst, 'reload schema';
