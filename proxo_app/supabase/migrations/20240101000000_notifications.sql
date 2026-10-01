-- ─────────────────────────────────────────────────────────────────────────────
-- Proxo — Notifications Tables Setup
-- Run this in Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. pa_device_tokens ────────────────────────────────────────────────────
-- FCM توکێنی هەر مۆبایلێک بۆ هەر یوزەرێک

create table if not exists pa_device_tokens (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  token       text        not null,
  platform    text        not null default 'android', -- 'android' | 'ios'
  updated_at  timestamptz not null default now(),
  unique(user_id, token)
);

alter table pa_device_tokens enable row level security;

create policy "user owns tokens"
  on pa_device_tokens for all
  using (auth.uid() = user_id);

-- ── 2. pa_notifications ────────────────────────────────────────────────────
-- هەموو ئاگاداریەکان کە لە ناو ئەپ پیشان دەدرێن

create table if not exists pa_notifications (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  type        text        not null default 'general',
  title       text,
  body        text,
  meta        jsonb       default '{}',
  is_read     boolean     not null default false,
  created_at  timestamptz not null default now()
);

alter table pa_notifications enable row level security;

create policy "user reads own notifications"
  on pa_notifications for select
  using (auth.uid() = user_id);

create policy "user updates own notifications"
  on pa_notifications for update
  using (auth.uid() = user_id);

create policy "service can insert"
  on pa_notifications for insert
  with check (true); -- Edge Function uses service_role key

-- ── Index بۆ خێرا خوێندنەوە ────────────────────────────────────────────────
create index if not exists idx_notifications_user_unread
  on pa_notifications(user_id, is_read, created_at desc);

create index if not exists idx_device_tokens_user
  on pa_device_tokens(user_id);

-- ── 3. Realtime چالاک بکە ──────────────────────────────────────────────────
-- Run this in Supabase Dashboard > Database > Replication
-- or via SQL:

alter publication supabase_realtime add table pa_notifications;

-- ─────────────────────────────────────────────────────────────────────────────
-- دوای ئەمەشەوە:
-- 1. supabase functions deploy send-notification --no-verify-jwt
-- 2. supabase secrets set FIREBASE_PROJECT_ID=your-project-id
-- 3. supabase secrets set FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@xxx.iam.gserviceaccount.com
-- 4. supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
-- ─────────────────────────────────────────────────────────────────────────────
