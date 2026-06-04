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


-- ============================================================
-- 参加者向け「公開進行ビュー」用テーブル（?view=shareId で匿名閲覧）
-- 主催者が自分の行だけ書き込み、閲覧は誰でも可（read-only公開）。
-- data には参加者名・進行などの掲示板情報のみ。秘密情報は入れないこと。
-- ============================================================
create table if not exists public.tournament_shares (
  id         text primary key,                       -- 共有ID（主催者ごとのランダム文字列）
  user_id    uuid references auth.users(id) on delete cascade,
  data       jsonb not null,                          -- 公開スナップショット（mode/cfg/dbl/sgl ほか）
  updated_at timestamptz not null default now()
);

alter table public.tournament_shares enable row level security;

-- 閲覧は誰でも可（匿名キーで読める＝公開ビュー）
create policy "tournament_shares public read" on public.tournament_shares
  for select using (true);

-- 追加・更新は所有者のみ
create policy "tournament_shares owner insert" on public.tournament_shares
  for insert with check (auth.uid() = user_id);
create policy "tournament_shares owner update" on public.tournament_shares
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ============================================================
-- QR自己エントリー（参加者が ?entry=shareId から名前を送信）
-- 参加者は匿名で追加(insert)のみ可。閲覧/更新/削除は当該shareの所有者だけ。
-- 主催者アプリがポーリングして名簿へ取込→ merged=true に更新。
-- ============================================================
create table if not exists public.self_entries (
  id         uuid primary key default gen_random_uuid(),
  share_id   text not null,
  mode       text,                                    -- 'doubles' | 'singles'
  name_a     text not null,
  name_b     text,                                    -- ダブルスの相方（任意）
  merged     boolean not null default false,          -- 主催者が名簿へ取込済み
  created_at timestamptz not null default now()
);

alter table public.self_entries enable row level security;

-- 参加者（匿名）は追加のみ可
create policy "self_entries anon insert" on public.self_entries
  for insert with check (true);

-- 閲覧は当該shareの所有者のみ
create policy "self_entries owner read" on public.self_entries
  for select using (exists (
    select 1 from public.tournament_shares s
    where s.id = self_entries.share_id and s.user_id = auth.uid()
  ));

-- 更新（merged化）は所有者のみ
create policy "self_entries owner update" on public.self_entries
  for update using (exists (
    select 1 from public.tournament_shares s
    where s.id = self_entries.share_id and s.user_id = auth.uid()
  ));

-- 削除は所有者のみ
create policy "self_entries owner delete" on public.self_entries
  for delete using (exists (
    select 1 from public.tournament_shares s
    where s.id = self_entries.share_id and s.user_id = auth.uid()
  ));
