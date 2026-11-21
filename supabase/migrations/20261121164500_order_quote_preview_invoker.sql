-- ex_order_quote_preview reads only ex_rates, which signed-in customers may already read
-- (policy ex_rates_select_auth), and calls two functions they may already call. It needs no
-- extra rights, so it runs with the caller's own.
alter function public.ex_order_quote_preview(text, text, numeric) security invoker;
