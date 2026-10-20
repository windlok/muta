// İstemciden tek bir ürün URL'si alır, fiyat bilgisini döndürür.
// Kullanım: supabase.functions.invoke('scrape-price', { body: { url } })

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { debugFetch, scrapeProduct } from '../_shared/scraper.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const body = await req.json();
    const url = (body?.url ?? '').toString().trim();
    if (!url) {
      return Response.json({ error: 'url gerekli' }, { status: 400, headers: cors });
    }
    if (!/^https?:\/\//i.test(url)) {
      return Response.json({ error: 'Geçersiz URL' }, { status: 400, headers: cors });
    }

    if (body?.debug === true) {
      const debug = await debugFetch(url);
      return Response.json(debug, { headers: cors });
    }

    const result = await scrapeProduct(url);
    return Response.json(result, {
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return Response.json(
      { error: e instanceof Error ? e.message : String(e) },
      { status: 500, headers: cors },
    );
  }
});
