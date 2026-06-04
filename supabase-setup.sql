-- ダーツ ハウストーナメント運営：クラウド保存テーブル
-- Supabase の SQL Editor に貼り付けて Run してください。
-- ユーザーごとに1行（自分のデータだけ読み書き可：行レベルセキュリティ）。

create table if not exists public.app_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.app_state enable row level security;

-- 自分の行だけ参照
create policy "select own" on public.app_state
  for select using (auth.uid() = user_id);

-- 自分の行だけ追加
create policy "insert own" on public.app_state
  for insert with check (auth.uid() = user_id);

-- 自分の行だけ更新
create policy "update own" on public.app_state
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
