# ダーツ ハウストーナメント運営アプリ

ダーツバーのハウストーナメント運営ツール。参加者を入力するだけで、総当たり（ロビン）→
決勝/ルーザートーナメント、またはシングルスの勝ち抜きトーナメントを自動生成し、
店舗の台数を設定して各試合がどの台かを可視化する。**ダブルス主体**＋当日募集のシングルス。

> このファイルは開発引き継ぎ用（別PC／新セッション）。Claude Code が自動で読み込む前提。
> 仕様・現状・実行方法・次の候補をまとめている。**作業前にこれを読めば現状がわかる**こと。

## 技術構成
- **単一HTMLファイル `index.html`**（約1290行）。ビルド不要。React 18 + Babel standalone + Tailwind + **Supabase** をすべてCDNで読込、ブラウザ実行。
- 状態は **localStorage**（キー接頭辞 `darts_`）。Supabase接続時は**クラウド保存も併用**（後述）。
- UIは **ライト（白地・罫線）テーマ**。
- ユーザーは普段 **file://**（`index.html` を直接ダブルクリック）で確認。スクショ(preview_screenshot)はTailwind CDNで詰まりがちなので、検証は `preview_eval` のDOM評価＋`preview_console_logs` で行う。
- GitHub: `Moko-04/darts-tournament`（private）にpush済（git user=Moko-04 / Moko-04@users.noreply.github.com）。

## 実行方法
- `node server.js` → 簡易静的サーバ http://localhost:4321
- または `index.html` をブラウザ（Chrome）で直接開く（CDN利用のためネット必要）
- Claude Code プレビュー: `.claude/launch.json` の `darts`（node server.js / port 4321）。

## 2イベント構成（モード切替）
画面上部トグルで **ダブルス / シングルス** を切替。
- 共有state = `cfg{store, boards, groups}`。
- イベント別state = `dbl` / `sgl` ＝ `{teams, groups, rr, brk:{winners,losers}, assign}`。
- アクティブイベント参照: `ev = mode==='doubles' ? dbl : sgl`。`teams/groups/rr/brk/assign` とその setter はこの `ev` を指す（既存関数が両モードで動く）。`isS = mode==='singles'`。

### ダブルス（tabs: 設定 / エントリー / 組分け / ロビン表 / トーナメント）
- エントリー = ペア枠（選手A・B、行追加式）＋シングル枠（相方募集チップ、D&Dで相方指定/ペア化）。`entriesToTeams(pairs, singles)` で未ペアのシングルは自動ペア化。
- 組分け = グループにランダム配置＋ドラッグで手動移動。**各組は最低4チーム**（`MIN_PER_GROUP=4`）。グループ数ステッパーは min2／max=floor(チーム数/4) で動的制限、`generate()`/`changeGroupCount` でも検証。例: 12チーム→最大3グループ。
- ロビン表 = グループごと総当たり、罫線つき。決勝進出数は `advanceFor(cfg.groups)`（4組→2 / 5組以上→3）。
- トーナメント = 決勝＋ルーザー（ロビン終了で自動作成）。

### シングルス（tabs: **エントリー / トーナメント のみ**）
- 設定/組分け/ロビンは**無し**。当日募集の個人戦。
- エントリー = **行リスト**（番号 + ⠿並び替え + 入力欄 + ×。sm以上は2列で圧縮、まとめ貼付details）。state = `sNames[]`。
- **全員で1本の勝ち抜きトーナメント**（`buildBracket(sNames)`）。グループ/ロビン/ルーザー無し。

## ロビン表（ダブルス）
- 罫線（`.rr-grid`）つき総当たり表。マスに対戦順 ①②③（4/5名は **`FIXED_SCHEDULES`** で指定順、他は `scheduleOrder` 円卓式）。
- マスtap = 予定→試合中（オレンジ）、再tap = 結果入力ウィンドウ（+/−スコア＋試合台ピッカー）。次の試合は青、確定で台自動クリア（N番台バッジ）。
- 順位 = 勝 → 直接対決H2H → レッグ差。

## トーナメント
- 明るいコンパクトカードのブラケット（`.bk / .bk-mg / .bk-card / .bk-slot`）。
- 勝者を **○** ＋淡い緑、**勝者の連結線は赤**で勝ち上がり可視化。
- 各試合に **試合台バッジ＋ピッカー**（`.bk-board / .bk-picker`、使用中の台は選択不可、勝者確定で台クリア）。
- 台数 `cfg.boards` 既定8・最大20。**ボード状況タブは廃止**（台は各試合に直接表示）。

## ログイン / クラウド保存（Supabase・実装済・動作確認済）
- `index.html` 上部に `SUPABASE_URL` ＋ `SUPABASE_ANON`（**publishable 公開キー** `sb_publishable_...`、公開OK）。
  両方セット時 `AUTH_ENABLED=true` → **ログイン必須＋クラウド保存**。空なら従来どおりログイン無し・localStorageのみ。
- ⚠️ クライアントに置くのは **publishable(anon) 公開キーのみ**。`service_role`（秘密）キーは絶対にコードに貼らない（データはRLSで保護）。
- テーブル `public.app_state(user_id uuid pk, data jsonb, updated_at)` ＋ RLS（自分の行のみ）。SQLは repo の **`supabase-setup.sql`**。
- `cloudLoad(uid)` = ローカルクリア後に自分のdataを反映 / `cloudSave(uid)` = `STATE_KEYS` をJSONでupsert（変更を1.5秒デバウンス）。`Root`(認証ラッパー) / `Login` / `Splash` コンポーネント。ヘッダーにメール表示＋ログアウト。
- **テストアカウント: t_suzuki@dart-ace.com / `REDACTED`**（メール確認済）。Supabaseは「Confirm email」ON。
- `STATE_KEYS = [mode, cfg, pairs, singles, sNames, dbl, sgl]`（export/import JSON もこのキー）。

## データモデル
- 共有: `cfg{store, boards, groups}` / `pairs[{id,a,b}]` / `singles[name]`（相方募集中）/ `sNames[]`（シングルス名簿）/ `mode`
- イベント別 `dbl`/`sgl`: `teams[{id,name,members,solo}]` / `groups[[teamId,...]]` / `rr{gi:{"a_b":{a,b,sa,sb,winner}}}`（a<b正規化）/ `brk{winners,losers}`（各 `{rounds:[[match,...]]}`）/ `assign{matchId:boardNo}`

## 主要関数（index.html 内）
- `advanceFor(g)` 決勝進出数 / `circled(n)` 丸数字 / `FIXED_SCHEDULES` 4・5名の対戦順 / `scheduleOrder(ids)` 円卓式
- `entriesToTeams(pairs, singles)` / `namesToTeams(names)`（後者はほぼ未使用）
- `buildBracket(seeds)` / `resolveSlot` / `matchWinner` トーナメント
- `cloudLoad(uid)` / `cloudSave(uid)` / `exportData()` / `importData(file)`

## 開発用
- `DEV_SEED=true` ＋ `DEV_PAIRS`(17組) ＋ `DEV_SINGLES`(16名)。空なら自動投入、設定タブに「投入(やり直し)」、ロビン表ヘッダーに「🧪全試合ランダム結果」ボタン。
- **公開/販売前に `DEV_SEED=false`** にすること。
- `test-17.json` = 17ペアのimport用フィクスチャ。

## 注意点・既知の仕様
- グループ数変更で即再振り分け（`changeGroupCount`）。設定と `groups` がズレると警告バナー＋ワンクリック修正。
- localStorage は端末ごと。Supabase未接続時の端末間移動はエクスポート/インポート。
- Claude Code プレビューはユーザー実ブラウザと localStorage を共有しうる → UI操作で検証、テストデータは最後にクリア。

## フェーズ進行（自社利用 → 将来販売）
- **フェーズ1（済）**: ログイン＋クラウド保存（Supabase）。動作確認済（店舗名マーカーが logout→login で保持されることを確認）。
- **次にやる候補**:
  1. **公開URLへデプロイ**（GitHub連携 Vercel か Netlify）＋ Supabase Authentication → URL Configuration の **Site URL / Redirect URLs を公開URLに設定**（確認メールリンク用）。
  2. **アプリ内パスワード変更UI**（`supa.auth.updateUser`）。
  3. 機能の壁打ち継続。
- **フェーズ2（後）**: マルチテナントSaaS（RLSは既にuser単位。店舗/契約モデル＋ Stripe課金）。

## 未決の壁打ち候補
文言「人/チーム」統一、3位決定戦、会場掲示用の大画面ボードビュー、台の自動繰り上げ。
