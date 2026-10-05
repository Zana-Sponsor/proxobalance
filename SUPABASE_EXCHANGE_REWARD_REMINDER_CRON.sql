-- Hourly server reminders also reach customers while the website is closed.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('exchange-reward-reminders','0 * * * *',
 'select public.ex_reward_emit_reminders();');

