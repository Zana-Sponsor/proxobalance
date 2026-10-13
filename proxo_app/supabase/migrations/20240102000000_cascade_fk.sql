-- ─────────────────────────────────────────────────────────────────────────────
  -- Proxo — Fix Foreign Key Constraints: ON DELETE CASCADE
  -- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
  --
  -- ئەمە دڵنیا دەکاتەوە کە کاتێک یوزەرێک لە auth.users دەسڕێتەوە،
  -- هەموو داتاکانی پەیوەندیدار بە خودی خۆی دەسڕێنەوە.
  -- ئەمجاوە ئیمێڵەکەش دەگەڕێتەوە بۆ تۆمارکردنی نوێ.
  -- ─────────────────────────────────────────────────────────────────────────────

  -- ── 1. profiles ────────────────────────────────────────────────────────────
  alter table if exists public.profiles
    drop constraint if exists profiles_id_fkey;

  alter table if exists public.profiles
    add constraint profiles_id_fkey
      foreign key (id)
      references auth.users(id)
      on delete cascade;

  -- ── 2. pa_wallets ──────────────────────────────────────────────────────────
  alter table if exists public.pa_wallets
    drop constraint if exists pa_wallets_user_id_fkey;

  alter table if exists public.pa_wallets
    add constraint pa_wallets_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 3. pa_transactions ─────────────────────────────────────────────────────
  alter table if exists public.pa_transactions
    drop constraint if exists pa_transactions_user_id_fkey;

  alter table if exists public.pa_transactions
    add constraint pa_transactions_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 4. pa_ads ──────────────────────────────────────────────────────────────
  alter table if exists public.pa_ads
    drop constraint if exists pa_ads_user_id_fkey;

  alter table if exists public.pa_ads
    add constraint pa_ads_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 5. pa_support ──────────────────────────────────────────────────────────
  alter table if exists public.pa_support
    drop constraint if exists pa_support_user_id_fkey;

  alter table if exists public.pa_support
    add constraint pa_support_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 6. pa_notifications (already has cascade from initial migration) ───────
  --    Double-check / re-apply just in case:
  alter table if exists public.pa_notifications
    drop constraint if exists pa_notifications_user_id_fkey;

  alter table if exists public.pa_notifications
    add constraint pa_notifications_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 7. pa_device_tokens (already has cascade from initial migration) ───────
  alter table if exists public.pa_device_tokens
    drop constraint if exists pa_device_tokens_user_id_fkey;

  alter table if exists public.pa_device_tokens
    add constraint pa_device_tokens_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 8. proxo_cards (if it exists) ─────────────────────────────────────────
  alter table if exists public.proxo_cards
    drop constraint if exists proxo_cards_user_id_fkey;

  alter table if exists public.proxo_cards
    add constraint proxo_cards_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ── 9. notifications (legacy table, if it exists) ─────────────────────────
  alter table if exists public.notifications
    drop constraint if exists notifications_user_id_fkey;

  alter table if exists public.notifications
    add constraint notifications_user_id_fkey
      foreign key (user_id)
      references auth.users(id)
      on delete cascade;

  -- ─────────────────────────────────────────────────────────────────────────────
  -- دوای ئەمەشەوە:
  -- ✅ هەر خشتەیەک کە user_id یان id ی auth.users هەیەتی
  --    بە خودی خۆی پاک دەبێتەوە کاتێک auth user دەسڕێتەوە
  -- ✅ ئیمێڵەکە دەگەڕێتەوە بۆ تۆمارکردنی نوێ
  -- ─────────────────────────────────────────────────────────────────────────────
  