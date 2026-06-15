-- 店舗サポート 報告書アプリ：Supabase セットアップ
-- SQL Editor に貼り付けて Run してください。
-- ※ クライアントに置くのは publishable(anon) 公開キーのみ。service_role は絶対に貼らない。

-- ============================================================
-- マスタ（担当者 / 店舗 / 項目カテゴリ）をユーザーごとに1行で保存
-- ============================================================
create table if not exists public.app_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.app_state enable row level security;

create policy "app_state select own" on public.app_state for select using (auth.uid() = user_id);
create policy "app_state insert own" on public.app_state for insert with check (auth.uid() = user_id);
create policy "app_state update own" on public.app_state for update using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ============================================================
-- 報告書レコード（任意・履歴をクラウドにも残したい場合）
-- ※ v1 では履歴は端末(localStorage)中心。クラウド一覧を使う場合に利用。
-- ============================================================
create table if not exists public.reports (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  store      text,
  report_at  timestamptz,
  staff      text[],
  data       jsonb not null default '{}',   -- 作業項目・特記事項など
  pdf_url    text,
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "reports select own" on public.reports for select using (auth.uid() = user_id);
create policy "reports insert own" on public.reports for insert with check (auth.uid() = user_id);
create policy "reports update own" on public.reports for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reports delete own" on public.reports for delete using (auth.uid() = user_id);


-- ============================================================
-- Storage バケット（PDF・写真）
-- ダッシュボード Storage で「reports」バケットを作成し Public ON。
-- 下記は SQL で作る場合（公開読み取り＋ログインユーザーのみ書き込み）。
-- ============================================================
insert into storage.buckets (id, name, public)
values ('reports', 'reports', true)
on conflict (id) do nothing;

create policy "reports bucket public read" on storage.objects
  for select using (bucket_id = 'reports');
create policy "reports bucket auth write" on storage.objects
  for insert to authenticated with check (bucket_id = 'reports');
create policy "reports bucket auth update" on storage.objects
  for update to authenticated using (bucket_id = 'reports');
