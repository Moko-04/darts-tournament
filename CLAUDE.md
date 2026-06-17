# ダーツ ハウストーナメント運営アプリ

ダーツバーのハウストーナメント運営ツール。参加者を入力するだけで、総当たり（ロビン）→
決勝/ルーザートーナメント、またはシングルスの勝ち抜きトーナメントを自動生成し、
店舗の台数を設定して各試合がどの台かを可視化する。**ダブルス主体**＋当日募集のシングルス。

> このファイルは開発引き継ぎ用（別PC／新セッション）。Claude Code が自動で読み込む前提。
> 仕様・現状・実行方法・次の候補をまとめている。**作業前にこれを読めば現状がわかる**こと。

## 技術構成
- **単一HTMLファイル `index.html`**。ビルド不要。React 18 + Babel standalone + Tailwind + **Supabase** + **qrcodejs**（公開ビューのQR用）をすべてCDNで読込、ブラウザ実行。
- ⚠️ **Babelは7系に固定必須**（`@babel/standalone@7.26.4`）。未固定だと **Babel 8** が配信され、JSXを自動ランタイムで出力→`import "react/jsx-runtime"` を注入→classicな `<script type="text/babel">` では実行不能→**画面が真っ白**になる（2026-06に発生・修正）。8系へ上げるならビルド方式に変える必要あり。
- 状態は **localStorage**（キー接頭辞 `darts_`）。Supabase接続時は**クラウド保存も併用**（後述）。
- UIは **ライト（白地・罫線）テーマ**。
- ユーザーは普段 **file://**（`index.html` を直接ダブルクリック）で確認。スクショ(preview_screenshot)はTailwind CDNで詰まりがちなので、検証は `preview_eval` のDOM評価＋`preview_console_logs` で行う。
- GitHub: `Moko-04/darts-tournament`（private）にpush済（git user=Moko-04 / Moko-04@users.noreply.github.com）。

## 実行方法
- `node server.js` → 簡易静的サーバ http://localhost:4321
- または `index.html` をブラウザ（Chrome）で直接開く（CDN利用のためネット必要）
- Claude Code プレビュー: `.claude/launch.json` の `darts`（node server.js / port 4321）。

## 3イベント構成（モード切替）
画面上部トグルで **ダブルス / シングルス / シングルストーナメント** を切替（`mode = 'doubles' | 'singlesrr' | 'singles'`）。
- 共有state = `cfg{store, boards, groups, groupsS, losersS}`（store/boardsは全モード共有。**グループ数はモード別**：`cfg.groups`=ダブルス／`cfg.groupsS`=シングルスsinglesrr。`cfg.losersS`=シングルスのルーザー有無・既定ON）。アクティブ値は `groupCount = mode==='doubles'?cfg.groups:(cfg.groupsS??4)`、変更は `setGroupCount(v)`。エントリー名簿：ダブルス=`pairs`+`singles`／シングルス2モードは **`sNames` を共有**（同じ人で両方式を回せる）。
- イベント別state = `dbl`（doubles）/ `sglR`（**新**singlesrr）/ `sgl`（singles＝ノックアウト）＝各 `{teams, groups, rr, brk:{winners,losers}, assign}`。
- アクティブイベント参照: `ev = mode==='doubles'?dbl : mode==='singlesrr'?sglR : sgl`。`teams/groups/rr/brk/assign` と setter はこの `ev` を指す（既存関数が全モードで動く）。
- **`isS = mode==='singles'`（=ノックアウト判定。意味は不変）／`indiv = mode!=='doubles'`（=個人戦、unit='人'）**。タブは `isS ? TABS_S : TABS_D`（doublesとsinglesrrは同じTABS_D、singlesだけTABS_S）。

### ダブルス（`doubles`・tabs: 設定 / エントリー / 組分け / ロビン表 / トーナメント）
- エントリー = ペア枠（選手A・B、行追加式）＋シングル枠（相方募集チップ、D&Dで相方指定/ペア化）。`entriesToTeams(pairs, singles)` で未ペアのシングルは自動ペア化。
- 組分け = グループにランダム配置＋ドラッグで手動移動。**各組の最低人数 = `minPerGroup(mode)`（ダブルス4／シングルスsinglesrr=3）**。グループ数ステッパーは min2／max=floor(人数/最低人数) で動的制限、`generate()`/`changeGroupCount` でも検証。例: ダブルス12チーム→最大3グループ。
- ロビン表 = グループごと総当たり、罫線つき。決勝進出数は **各組のチーム数** で決定：`advanceForSize(そのグループの人数)`（**4→上位2 / 5以上→上位3**）。`seedsFor` は組ごとに上位を集めてインターリーブ。
- トーナメント = 決勝＋ルーザー（ロビン終了で自動作成）。

### シングルス（`singlesrr`・新規・tabs: ダブルスと同じ5つ）
- **ダブルスの個人版**。エントリー（`sNames` の行リスト）→ `generate()` が `namesToTeams(sNames)`（1人1チーム）→ 組分け → ロビン表 → **決勝＋ルーザー**（ロビン終了で自動作成）。doublesと同じRRフローを `mode==='singlesrr'` 分岐で流用。unit='人'。
- エントリーのボタンは「組分けへ →」（KOは「トーナメント作成 →」）。
- **ルーザー有無トグル**（設定タブ・singlesrrのみ表示）：`cfg.losersS`（既定ON）。OFFなら決勝のみ作成（非進出者は敗退）。`withLosers = mode==='doubles' ? true : cfg.losersS!==false` を `TournamentTab`/`SnapshotView` に渡し、自動作成(effect deps)・`regen`・ルーザー表示・進出説明文をガード。ダブルスは常時ルーザーあり（トグル無し）。

### シングルストーナメント（`singles`・既存ノックアウト・tabs: **エントリー / トーナメント のみ**）
- 設定/組分け/ロビンは**無し**。当日募集の個人戦。エントリー = `sNames` の行リスト。
- **全員で1本の勝ち抜きトーナメント**（`buildBracket(sNames)`）。グループ/ロビン/ルーザー無し。
- ⚠️ このモードは設定タブが無い＝**「全データをリセット」ボタンも無い**（リセットしたい時はダブルス/シングルスタブの設定から）。

## ロビン表（ダブルス）
- 罫線（`.rr-grid`）つき総当たり表。マスに対戦順 ①②③（4/5名は **`FIXED_SCHEDULES`** で指定順、他は `scheduleOrder` 円卓式）。
- **次の試合＝青**。青（予定）マスtap = **台ピッカー**（対戦カード＋台選択のみ・スコア無し）→ **台を選ぶと「割当＋試合中＋自動で閉じる」**（`pickBoard`）。「台未定で開始」も可。
- 試合中/終了マスtap = 結果入力ウィンドウ（+/−スコア＋試合台ピッカー＋「予定に戻す」）。確定で台自動クリア（N番台バッジ）。
- モーダルは `eStatus`（予定/試合中/終了）で出し分け（`isPlanned` で開始モード ↔ 結果入力モード）。
- 順位 = 勝 → 直接対決H2H → レッグ差。

## トーナメント
- 明るいコンパクトカードのブラケット（`.bk / .bk-mg / .bk-card / .bk-slot`）。
- 勝者を **○** ＋淡い緑、**勝者の連結線は赤**で勝ち上がり可視化。
- **優勝列（👑）**：`BracketView` に `champTitle` を渡すと決勝（最終ラウンド）の右に「優勝」列を表示。決勝が確定すると勝者を👑＋金カードで表示（未確定は「優勝者待ち」）。決勝Tとシングルスのみ付与（ルーザーには付けない）。決勝mgに `bk-mg-final` を付け連結フックを抑制、優勝列は `.bk-champ`。👑は `.bk-champ-box` 内で**絶対配置**（カードは常時センター固定・確定してもずれない）。
- 各試合に **試合台バッジ＋ピッカー**（`.bk-board / .bk-picker`、使用中の台は選択不可、勝者確定で台クリア）。使用中判定は **決勝・ルーザー両ブラケット横断**：`TournamentTab` で `usedBoards` を集計し両 `BracketView` に渡す（同じ台を上下で重複設定できない）。シングルスは1本なので自己集計。
- 台数 `cfg.boards` 既定8・最大20。**ボード状況タブは廃止**（台は各試合に直接表示）。

## ログイン / クラウド保存（Supabase・実装済・動作確認済）
- `index.html` 上部に `SUPABASE_URL` ＋ `SUPABASE_ANON`（**publishable 公開キー** `sb_publishable_...`、公開OK）。
  両方セット時 `AUTH_ENABLED=true` → **ログイン必須＋クラウド保存**。空なら従来どおりログイン無し・localStorageのみ。
- ⚠️ クライアントに置くのは **publishable(anon) 公開キーのみ**。`service_role`（秘密）キーは絶対にコードに貼らない（データはRLSで保護）。
- テーブル `public.app_state(user_id uuid pk, data jsonb, updated_at)` ＋ RLS（自分の行のみ）。SQLは repo の **`supabase-setup.sql`**。
- `cloudLoad(uid)` = ローカルクリア後に自分のdataを反映 / `cloudSave(uid)` = `STATE_KEYS` をJSONでupsert（変更を1.5秒デバウンス）。`Root`(認証ラッパー) / `Login` / `Splash` コンポーネント。ヘッダーにメール表示＋ログアウト。
- **アクセスは承認制（自己登録なし）**: `Login` はログイン専用UI（signUp廃止）。発行依頼は「アカウント発行を依頼する（フォーム）」リンク → **Googleフォーム** `ACCOUNT_REQUEST_URL`（オーナーのGoogleアカウントで作成、回答→メール通知ON、「リンクを知っている全員」可）。`ACCOUNT_REQUEST_URL` が空なら `ADMIN_EMAIL` への mailto にフォールバック。フォーム編集は当該Googleアカウントの Forms から（質問: お名前必須/連絡先メール必須/店舗名任意）。オーナーが **Supabase ダッシュボードでユーザーを手動作成**（Authentication → Users → Add user → **Auto Confirm User** でメール送信不要＝メール上限も回避）。**Supabase側で公開サインアップもOFF**にすること（Authentication → Sign In/Providers の「Allow new users to sign up」）。
- **テストアカウント**: `t_suzuki@dart-ace.com`（メール確認済）。**パスワードはリポジトリに置かない**（オーナーのパスワードマネージャーで管理）。Supabaseは「Confirm email」ON。
- `STATE_KEYS = [mode, cfg, pairs, singles, sNames, dbl, sgl, sglR, checkin, shareId]`（export/import JSON もこのキー）。

## 当日チェックイン（来場確認・個人ごと）
- エントリー一覧の各個人に来場✓トグル。state = トップレベル `checkin{ personKey: true }`。personKey = `${pair.id}:a|b`（ペア）/ `sg:${i}`（相方募集）/ `sn:${i}`（シングルス名簿）。
- 受付バナー＋ヘッダーに「受付 来場/事前 人数」。未チェック＝未来場。再振り分けしてもエントリー単位なので保持。`toggleCheckin(key)` / `checkinCount`・`entrantCount`。
- **名前検索チェックイン** `CheckinSearch`（エントリータブ・受付バナー直下、両モード）：名前の一部を入力→候補をタップで来場/取消。各行の✓と併用。people=`{name,key}` で現在の名簿から生成。
- 将来のLINE連携（エントリー名→自動チェックイン）もこのキーに立てる想定。

## 参加者向け公開進行ビュー（`?view=shareId`・閲覧専用・自動更新）
- 主催者の進行を参加者が**ログイン不要で閲覧**。render分岐 `VIEW_ID`（`?view=`）で `PublicView` を描画（認証スキップ）。`shareId` は初回生成しSTATE_KEYSで同期。
- データ: 主催者ログイン中 `publishShare()` が `tournament_shares` に2秒デバウンスでupsert（自動公開）。`PublicView` は匿名キーで `tournament_shares` を**12秒ポーリング**。
- 表示は既存 `RoundRobin`/`BracketView` を **`readOnly` プロップ**で再利用（編集ハンドラ全ガード・モーダル/ピッカー/ドラッグ/DEVボタン非表示・台は静的バッジ）。純粋ヘルパーは module-level `makeHelpers(teams,groups,rr)`。
- 共有UI: 設定タブの `SharePanel`（公開URL＋コピー＋**QR**＝`qrcodejs`）。
- **要Supabase**: `tournament_shares` テーブル＋RLS（匿名read可・所有者のみwrite）。SQLは `supabase-setup.sql`。未作成だと公開ビューは「見つかりません」表示。

## QR自己エントリー（廃止・2026-06）
- 参加者がQRから名前送信→自動受付する機能は**削除**（`EntryQR`/`SelfEntry`/`submitSelfEntry`/`?entry=`取込ポーリング を撤去）。参加者向け通知は将来 LINE 等で再検討の方針（一旦保留）。
- 受付は**手動チェックイン**（各行✓＋`CheckinSearch` 名前検索）に一本化。
- DBの `self_entries` テーブル＋RLS は `supabase-setup.sql` に残置（復活時にそのまま使える。不要なら手動DROP可）。

## 大会履歴（過去の大会・アカウントごと）
- 設定タブの `HistoryPanel`：保存名（既定＝店名＋日付）＋「現在の大会を保存」→ `saveHistory()` が現在の状態（`currentBlob()`＝mode/cfg/pairs/singles/sNames/dbl/sgl/checkin）を `tournament_history` にinsert。
- **トーナメントタブ下部の「🏁 大会を終了して保存」**（`FinishBar`、両モード）も同じ `saveHistory(currentBlob())` を呼ぶ（名前＝店名＋日付）。終了＝保存のみ（データは消さない。クリアは設定の「全データをリセット」）。`TournamentTab` に `session` を渡して使用。
- 一覧（`listHistory`・新しい順）に名前/日時＋「表示」「削除」。表示＝全画面オーバーレイで `SnapshotView`（閲覧専用・順位表＋ブラケット）。
- `SnapshotView({snap,updatedAt,live})` は**公開ビュー(`?view=`)と履歴で共通**の読み取り表示（`PublicView` も内部でこれを使う）。`live` で「閲覧専用/履歴」バッジと更新文言を出し分け。
- **自動保存**：`resetAll`（全データをリセット）時、ログイン中＆中身がある場合は消去前に履歴へ自動保存（`saveHistory`）。保存失敗時は「それでも消去するか」を再確認（データ消失防止）。リセットは `checkin` もクリア。
- **要Supabase**: `tournament_history(id,user_id,name,data,created_at)`＋RLS（本人のみ全操作）。SQLは `supabase-setup.sql`。未作成だと保存が失敗（パネルにメッセージ）。

## データモデル
- 共有: `cfg{store, boards, groups(ダブルス), groupsS(シングルスsinglesrr), losersS(シングルスのルーザー有無・既定ON)}` / `pairs[{id,a,b}]` / `singles[name]`（相方募集中）/ `sNames[]`（シングルス名簿・**singlesrrとsinglesで共有**）/ `mode`（'doubles'|'singlesrr'|'singles'）/ `checkin{personKey:true}`（来場）/ `shareId`（公開ビューID）
- イベント別 `dbl`/`sglR`/`sgl`: `teams[{id,name,members,solo}]` / `groups[[teamId,...]]` / `rr{gi:{"a_b":{a,b,sa,sb,winner}}}`（a<b正規化）/ `brk{winners,losers}`（各 `{rounds:[[match,...]]}`）/ `assign{matchId:boardNo}`。singlesrrは `namesToTeams(sNames)` で1人1チーム化。公開/履歴スナップショットも `mode` で `dbl/sglR/sgl` を出し分け。

## 主要関数（index.html 内）
- `advanceForSize(n)` 各組の決勝進出数（n=その組のチーム数。5以上→3 / 4以下→2） / `circled(n)` 丸数字 / `FIXED_SCHEDULES` 4・5名の対戦順 / `scheduleOrder(ids)` 円卓式
- `entriesToTeams(pairs, singles)` / `namesToTeams(names)`（後者はほぼ未使用）
- `buildBracket(seeds)` / `resolveSlot` / `matchWinner` トーナメント
- `cloudLoad(uid)` / `cloudSave(uid)` / `exportData()` / `importData(file)`

## 開発用
- `DEV_SEED` ＋ `DEV_PAIRS`(17組) ＋ `DEV_SINGLES`(16名)。`true` のとき空なら自動投入、設定タブに「投入(やり直し)」、ロビン表ヘッダーに「🧪全試合ランダム結果」ボタンを表示。
- **2026-06 に `DEV_SEED=false`（本番運用）に変更済**。開発で再びテストデータが欲しいときだけ一時的に `true` に戻す。`false` の間は自動投入もDEVボタンも無し。
- `test-17.json` = 17ペアのimport用フィクスチャ。

## 注意点・既知の仕様
- グループ数変更で即再振り分け（`changeGroupCount`）。設定と `groups` がズレると警告バナー＋ワンクリック修正。
- localStorage は端末ごと。Supabase未接続時の端末間移動はエクスポート/インポート。
- Claude Code プレビューはユーザー実ブラウザと localStorage を共有しうる → UI操作で検証、テストデータは最後にクリア。

## デプロイ（公開URL）
- **本番URL: https://moko-04.github.io/darts-tournament/ **（GitHub Pages・main/root 配信・`.nojekyll`・HTTPS強制）。
- リポジトリは **public**（公開鍵のみ・service_roleは無し）。テストアカウントの旧PWは公開前にSupabaseで削除＋git履歴からも除去済（filter-branch＋force-push）。秘密情報はコミットしないこと。
- push で自動再ビルド（main へ push → Pages が再配信、約30秒）。ユーザーは普段 file:// でも確認可（CDN利用）。
- ⚠️ **Supabase Authentication → URL Configuration を公開URLに合わせること**（確認メール／パスワードリセットのリンク用）:
  - Site URL = `https://moko-04.github.io/darts-tournament/`
  - Redirect URLs = `https://moko-04.github.io/darts-tournament/**`（ローカル併用なら `http://localhost:4321/**` も）

## フェーズ進行（自社利用 → 将来販売）
- **フェーズ1（済）**: ログイン＋クラウド保存（Supabase）。動作確認済。
- **公開URLデプロイ（済）**: GitHub Pages（上記）。
- **次にやる候補**:
  1. **アプリ内パスワード変更UI**（`supa.auth.updateUser`）。
  2. 機能の壁打ち継続。
- **フェーズ2（後）**: マルチテナントSaaS（RLSは既にuser単位。店舗/契約モデル＋ Stripe課金）。

## 未決の壁打ち候補
文言「人/チーム」統一、3位決定戦、会場掲示用の大画面ボードビュー、台の自動繰り上げ。
