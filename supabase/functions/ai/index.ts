// Gemini proxy'si: API anahtarı sunucuda kalır, istemciye sızmaz.
//
// Kurulum:
//   supabase secrets set GEMINI_API_KEY=...
//   supabase functions deploy ai
//
// Kullanım (istemciden):
//   supabase.functions.invoke('ai', { body: { prompt: '...' } })

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GEMINI_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const MODEL = 'gemini-3.8-flash';
const MAX_PROMPT_LENGTH = 12000;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  if (!GEMINI_KEY) {
    return json({ error: 'GEMINI_API_KEY tanımlı değil' }, 500);
  }

  try {
    const { prompt, language } = await req.json();
    const text = (prompt ?? '').toString().trim();
    const lang = language === 'tr' ? 'tr' : 'en';

    if (!text) return json({ error: 'prompt gerekli' }, 400);
    if (text.length > MAX_PROMPT_LENGTH) {
      return json({ error: 'prompt çok uzun' }, 413);
    }

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text }] }],
          generationConfig: {
            temperature: 0.35,
            // Gemini 3 thinking tokens also count toward the output budget.
            // A low budget leaves enough room for the full JSON response.
            maxOutputTokens: 8192,
            responseMimeType: 'application/json',
            thinkingConfig: { thinkingLevel: 'low' },
          },
          systemInstruction: {
            parts: [
              {
                text:
                  lang === 'tr'
                    ? 'Sen Türkçe konuşan bir kişisel asistansın. Kısa, net ve yapıcı yanıtlar ver. ' +
                      'Kullanıcı günlük işlerini ve alışveriş takibini yönetiyor. ' +
                      'Tarihleri Türkiye zaman dilimine göre düşün. Sadece istenen JSON yapısını döndür.'
                    : 'You are a concise, practical personal assistant. ' +
                      'The user manages daily tasks and shopping price tracking. ' +
                      'Use a realistic daily schedule. Return only the requested JSON structure.',
              },
            ],
          },
        }),
      },
    );

    if (!res.ok) {
      const errText = await res.text();
      return json({ error: `Gemini ${res.status}`, detail: errText }, 502);
    }

    const data = await res.json();
    const finishReason = data?.candidates?.[0]?.finishReason ?? null;
    const out =
      data?.candidates?.[0]?.content?.parts
        ?.map((part: { text?: string }) => part.text ?? '')
        .join('') ?? '';

    return json({ text: out, finishReason });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
