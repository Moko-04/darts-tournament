// Supabase Edge Function: send-line
// 完了時にクライアントから呼ばれ、LINE Messaging API でグループ/ユーザーへ push する。
//
// デプロイ:
//   supabase functions deploy send-line
// シークレット設定（service_role等は不要・LINE のトークンと送信先のみ）:
//   supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=xxxxx
//   supabase secrets set LINE_TO=Cxxxxxxxx        # 送信先のグループID or ユーザーID
//
// ※ JWT検証は有効（既定）。ログイン済みユーザーのみ呼べる。
//   LINE はメッセージで PDF を直接送れないため、PDFはURLリンクで送り、表紙画像があれば画像も送る。

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const token = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN");
    const to = Deno.env.get("LINE_TO");
    if (!token || !to) {
      return json({ error: "LINE_CHANNEL_ACCESS_TOKEN / LINE_TO が未設定です。" }, 500);
    }

    const { text, pdfUrl, imageUrl } = await req.json();

    const messages: unknown[] = [];
    const body = [text || "作業報告", pdfUrl ? `PDF: ${pdfUrl}` : ""].filter(Boolean).join("\n");
    messages.push({ type: "text", text: body.slice(0, 5000) });
    // 画像は https かつ公開URLのみ有効
    if (imageUrl && /^https:\/\//.test(imageUrl)) {
      messages.push({ type: "image", originalContentUrl: imageUrl, previewImageUrl: imageUrl });
    }

    const res = await fetch("https://api.line.me/v2/bot/message/push", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` },
      body: JSON.stringify({ to, messages }),
    });

    if (!res.ok) {
      const detail = await res.text();
      return json({ error: "LINE送信に失敗しました", detail }, 502);
    }
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}
