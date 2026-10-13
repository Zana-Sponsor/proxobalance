-- Operator-only cleanup after separate, explicit user approval. Do not invoke
-- this from deployment, verification, or the non-destructive cutover script.
do $$ begin
 if current_setting('proxolink.legacy_cleanup_approved',true) is distinct from 'true'
 then raise exception 'Separate user approval is required before legacy cleanup'; end if;
 if not exists(select 1 from proxolink_private.cards_backup_20261003)
 then raise exception 'Verified private customer backup is required'; end if;
 if exists(select 1 from public.proxolink_cards where publish_status<>'ready')
 then raise exception 'Verify every customer card before legacy cleanup'; end if;
end $$;

alter table public.proxolink_cards drop column html_content;
alter table public.proxolink_cards drop column avatar_b64;
alter table public.proxolink_cards drop column logo_b64;
