-- The export runs as anon (3 s limit). It takes well under a second today, but the
-- tables grow; PostgREST applies a function's own statement_timeout to the call.
alter function public.ex_backup_export(text) set statement_timeout = '60s';
