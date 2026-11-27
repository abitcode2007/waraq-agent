-- ============================================================
-- WARAQ — مخطط قاعدة البيانات وسياسات الأمان
-- نفّذ هذا الملف في: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1) جدول مزامنة بيانات المستخدم
create table if not exists public.user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists user_data_updated_at_idx on public.user_data (updated_at desc);

-- 2) تفعيل RLS — أهم خطوة أمنية في المشروع
alter table public.user_data enable row level security;

drop policy if exists "user_data_select_own" on public.user_data;
drop policy if exists "user_data_insert_own" on public.user_data;
drop policy if exists "user_data_update_own" on public.user_data;
drop policy if exists "user_data_delete_own" on public.user_data;

create policy "user_data_select_own" on public.user_data
  for select to authenticated
  using (auth.uid() = user_id);

create policy "user_data_insert_own" on public.user_data
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "user_data_update_own" on public.user_data
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_data_delete_own" on public.user_data
  for delete to authenticated
  using (auth.uid() = user_id);

-- 3) Bucket ملفات PDF — خاص، بحجم ونوع مقيّدين على مستوى الخادم
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pdfs', 'pdfs', false, 15728640, array['application/pdf']::text[])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 4) سياسات Storage: كل مستخدم يصل لمجلده فقط (user.id/xxx.pdf)
drop policy if exists "pdfs_select_own" on storage.objects;
drop policy if exists "pdfs_insert_own" on storage.objects;
drop policy if exists "pdfs_update_own" on storage.objects;
drop policy if exists "pdfs_delete_own" on storage.objects;

create policy "pdfs_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'pdfs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pdfs_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'pdfs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pdfs_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'pdfs' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'pdfs' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pdfs_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'pdfs' and (storage.foldername(name))[1] = auth.uid()::text);

-- 5) مقاطع ملفات PDF للبحث الدلالي (الفهرسة تتم في المتصفح بمفتاح المستخدم)
create table if not exists public.chunks (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id text not null,
  file_id text not null,
  page integer not null,
  content text not null,
  embedding text not null,
  created_at timestamptz not null default now()
);
create index if not exists chunks_user_subject_idx on public.chunks (user_id, subject_id);
alter table public.chunks enable row level security;
drop policy if exists "chunks_all_own" on public.chunks;
create policy "chunks_all_own" on public.chunks
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 6) تحديد معدل استخدام المساعد (15 طلب/دقيقة، 200 طلب/يوم)
create table if not exists public.chat_usage (
  user_id uuid primary key references auth.users(id) on delete cascade,
  minute_bucket bigint not null,
  minute_count integer not null default 0,
  day_bucket text not null,
  day_count integer not null default 0
);
alter table public.chat_usage enable row level security;
-- لا توجد سياسات للعملاء؛ الدالة أدناه هي الوحيدة المخوّلة بالكتابة.

create or replace function public.chat_rate_limit(
  p_user uuid,
  p_limit_minute integer default 15,
  p_limit_day integer default 200
) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  r public.chat_usage;
  minute_b bigint := floor(extract(epoch from now()) / 60)::bigint;
  day_b text := to_char(now() at time zone 'utc', 'YYYY-MM-DD');
begin
  insert into public.chat_usage (user_id, minute_bucket, minute_count, day_bucket, day_count)
  values (p_user, minute_b, 1, day_b, 1)
  on conflict (user_id) do update set
    minute_count = case when chat_usage.minute_bucket = minute_b then chat_usage.minute_count + 1 else 1 end,
    minute_bucket = minute_b,
    day_count = case when chat_usage.day_bucket = day_b then chat_usage.day_count + 1 else 1 end,
    day_bucket = day_b
  returning * into r;
  return r.minute_count <= p_limit_minute and r.day_count <= p_limit_day;
end $$;

revoke all on function public.chat_rate_limit(uuid, integer, integer) from public, anon;
grant execute on function public.chat_rate_limit(uuid, integer, integer) to authenticated;

-- ============================================================
-- إعدادات تُضبط من لوحة Supabase (لا تُنفّذ هنا):
--   Authentication → Providers → Email:
--     Confirm email = ON
--     Secure email change = ON
--   Authentication → Security:
--     Leaked password protection = ON
--     CAPTCHA = ON
--   Project Settings → API → JWT expiry = 3600
--  المساعد لا يحتاج Edge Function ولا GEMINI_API_KEY: كل مستخدم يدخل مفتاحه في الواجهة.
--  جدول chunks أعلاه مطلوب لتعمل فهرسة PDF والبحث داخل الملفات.
-- ============================================================
