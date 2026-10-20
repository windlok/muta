// Cron: Aktif ürünleri düzenli aralıklarla kontrol eder.
// Fiyat düşünce `notifications` tablosuna kayıt ekler; uygulama Realtime ile
// bunu canlı olarak görür. (Supabase cron.sql ile her 3 saatte bir çağrılır.)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { scrapeProduct } from '../_shared/scraper.ts';

serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: products } = await supabase
    .from('tracked_products')
    .select('*')
    .eq('is_active', true)
    .limit(200);

  let checked = 0;
  let alerts = 0;

  for (const p of products ?? []) {
    try {
      const result = await scrapeProduct(p.url);
      if (result.price == null) continue;

      const previous = p.current_price as number | null;
      const price = result.price;

      await supabase
        .from('price_history')
        .insert({ product_id: p.id, price });

      await supabase
        .from('tracked_products')
        .update({
          current_price: price,
          updated_at: new Date().toISOString(),
        })
        .eq('id', p.id);

      const tokens = await loadTokens(supabase, p.user_id as string);
      const language = tokens[0]?.language === 'tr' ? 'tr' : 'en';
      const alert = buildAlert(p, previous, price, language);
      if (alert) {
        await supabase.from('notifications').insert({
          user_id: p.user_id,
          type: 'price_alert',
          title: alert.title,
          body: alert.body,
        });
        alerts++;
        try {
          await sendPush(supabase, tokens, p, previous, price);
        } catch (e) {
          console.warn('Push gönderilemedi:', e);
        }
      }
      checked++;
    } catch (e) {
      console.warn('Fiyat çekilemedi:', p.url, e);
    }

    // Anti-bot: rastgele gecikme (800-2800 ms).
    await new Promise((r) => setTimeout(r, 800 + Math.random() * 2000));
  }

  return Response.json({ checked, alerts });
});

function buildAlert(
  p: Record<string, unknown>,
  previous: number | null,
  price: number,
  language: string,
): { title: string; body: string } | null {
  if (!p.notify_on_drop) return null;

  const tr = language === 'tr';
  const type = (p.alert_type as string) || 'target';
  const name = String(p.name);
  const target = p.target_price as number | null;

  if (type === 'target') {
    if (target == null || price > target) return null;
    // Aynı seviyede her kontrolde tekrar bildirim gönderme.
    if (previous != null && previous <= target) return null;
    return {
      title: tr ? 'Fiyat hedefe ulaştı!' : 'Price target reached!',
      body: tr
        ? `${name} · ₺${price} (hedef ₺${target})`
        : `${name} · ₺${price} (target ₺${target})`,
    };
  }

  if (previous == null || price >= previous) return null;

  if (type === 'drop') {
    return {
      title: tr ? 'Fiyat düştü!' : 'Price dropped!',
      body: `${name} · ₺${previous} → ₺${price}`,
    };
  }

  if (type === 'percent') {
    const threshold = Math.max(1, (p.alert_percent as number | null) ?? 10);
    const dropPercent = ((previous - price) / previous) * 100;
    if (dropPercent < threshold) return null;
    return {
      title: tr
        ? `Fiyat %${Math.round(dropPercent)} düştü!`
        : `Price dropped ${Math.round(dropPercent)}%!`,
      body: `${name} · ₺${previous} → ₺${price}`,
    };
  }

  return null;
}

// --- FCM push: uygulama kapalıyken de telefon bildirimi ---

type DeviceToken = { token: string; language: string | null };

let fcmCache: { token: string; expiresAt: number } | null = null;

async function loadTokens(
  supabase: any,
  userId: string,
): Promise<DeviceToken[]> {
  const { data } = await supabase
    .from('device_tokens')
    .select('token, language')
    .eq('user_id', userId);
  return (data ?? []) as DeviceToken[];
}

async function sendPush(
  supabase: any,
  tokens: DeviceToken[],
  p: Record<string, unknown>,
  previous: number | null,
  price: number,
): Promise<void> {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw || tokens.length === 0) return; // Servis hesabı yoksa push atlanır.

  const sa = JSON.parse(raw) as {
    client_email: string;
    private_key: string;
    project_id: string;
  };

  const accessToken = await fcmAccessToken(sa);

  await Promise.all(
    tokens.map(async ({ token, language }) => {
      const alert = buildAlert(
        p,
        previous,
        price,
        language === 'tr' ? 'tr' : 'en',
      );
      if (!alert) return;
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title: alert.title, body: alert.body },
                android: { notification: { channel_id: 'price_alerts' } },
              },
            }),
          },
        );
        if (res.status === 404) {
          // UNREGISTERED: uygulama silinmiş; token'ı temizle.
          await supabase.from('device_tokens').delete().eq('token', token);
        }
      } catch (e) {
        console.warn('Push gönderilemedi:', e);
      }
    }),
  );
}

async function fcmAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (fcmCache && fcmCache.expiresAt > now + 120) return fcmCache.token;

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

  const unsigned = `${enc({ alg: 'RS256', typ: 'JWT' })}.${enc({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;

  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const keyBytes = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${sig}`,
    }),
  });
  if (!res.ok) {
    throw new Error(`FCM erişim anahtarı alınamadı: ${res.status}`);
  }
  const data = await res.json();
  fcmCache = {
    token: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return data.access_token;
}
