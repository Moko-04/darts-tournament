# 店舗サポート 報告書アプリ

店舗サポート事業部の作業報告書を **携帯で完結** して作成するツール。
店舗・日時・担当・項目カテゴリを選び、各作業の **施工前 / 施工後** 写真と特記事項を入力 →
**「完了」で PDF を生成して LINE 送信**（Messaging API）します。

> ⚠️ このフォルダは独立アプリです。`Moko-04/darts-tournament` の作業ブランチ内で試作中。
> 固まったら下記「別リポジトリへの切り出し」で `store-support-report` 単独リポジトリへ移します。

## 技術構成
- **単一HTMLファイル `index.html`**。ビルド不要。React 18 + Babel standalone + Tailwind +
  Supabase + **html2canvas + jsPDF**（PDF生成）をすべて CDN 読込、ブラウザ実行。
- 保存は **localStorage**（キー接頭辞 `ssr_`）。Supabase 設定時はクラウド保存＋写真/PDFアップロード＋LINE自動送信。
- 設定が空でも動作（ログイン無し・端末保存のみ・PDFは共有/ダウンロードで対応）。

## 画面
- **作成**：店舗(選択) / 日時 / 担当(複数チップ) → 作業項目(カテゴリ＋施工前後の写真＋メモ)を複数 → 特記事項 → **完了して送信**。
- **履歴**：過去の報告書一覧。PDF再共有・クラウドPDFリンク・削除。
- **設定**：担当者 / 店舗 / 項目カテゴリ の各マスタ編集。

## 実行
- `node server.js` → http://localhost:4322
- または `index.html` を Chrome で直接開く（CDN利用のためネット必要）。

## 「完了 → LINE送信」の仕組み
1. 入力内容を PDF 化（HTMLレイアウトを html2canvas でキャプチャ → jsPDF）。
2. （Supabase設定時）写真の表紙画像と PDF を Storage バケット `reports` にアップロード。
3. Edge Function `send-line` を呼び、LINE Messaging API で送信先へ push（本文＋PDFリンク＋表紙画像）。
4. Supabase 未設定 / LINE失敗時は、端末の **共有シート（Web Share）** か **ダウンロード** にフォールバック。

## セットアップ（クラウド＋LINEを使う場合）
### 1. Supabase
1. プロジェクト作成 → `supabase-setup.sql` を SQL Editor で実行（テーブル・RLS・Storage `reports` バケット）。
2. `index.html` 上部の `SUPABASE_URL` と `SUPABASE_ANON`（**publishable 公開キー**）を入力。
3. Authentication で「Allow new users to sign up」を OFF にし、ユーザーは **Add user → Auto Confirm** で手動発行。

### 2. LINE Messaging API
1. [LINE Developers](https://developers.line.biz/) で **Messaging API チャネル**（LINE公式アカウント）を作成。
2. **チャネルアクセストークン（長期）** を発行。
3. 送信先（グループ or ユーザー）の ID を取得：
   - 公式アカウントを送信したいグループに招待 → Webhook で受け取る `groupId`（または1対1なら `userId`）。
4. Edge Function をデプロイ＆シークレット設定：
   ```bash
   supabase functions deploy send-line
   supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=＜トークン＞
   supabase secrets set LINE_TO=＜groupId または userId＞
   ```
   - トークン・送信先IDは **Supabase のシークレット（サーバ側）** に置く。コードやリポジトリには貼らない。

## データモデル
- マスタ（localStorage / app_state.data）：`staff[]` / `stores[]` / `categories[]`
- 報告書 `report`：`{ id, store, date, staff[], items:[{category, before[], after[], note}], note, createdAt, pdfUrl? }`
  - 写真は端末では縮小JPEGの dataURL。クラウド時は Storage の公開URL（表紙＋PDF）。

## 別リポジトリへの切り出し（このフォルダ → 単独リポジトリ）
GitHub で空の `store-support-report` リポジトリを作成後、ローカルで：
```bash
# darts-tournament の作業ブランチをチェックアウトした状態で
git subtree split --prefix=store-support-report -b ssr-only
mkdir ../store-support-report && cd ../store-support-report && git init
git pull /path/to/darts-tournament ssr-only
git remote add origin git@github.com:Moko-04/store-support-report.git
git push -u origin main
```
（または単純にこのフォルダの中身を新規リポジトリへコピーして初回コミットでも可。）

## 公開（GitHub Pages）
単独リポジトリ化後、main/root 配信 + `.nojekyll`。Supabase の Authentication → URL Configuration を公開URLに合わせること。
