// Paylaşılan fiyat çekme mantığı (Deno · Supabase Edge Functions).
//
// Edge Function'lar Chrome içermez; bu yüzden Puppeteer yerine
// cheerio ile statik HTML ayrıştırılır. JS ile fiyat üreten sitelerde
// OG (OpenGraph) meta etiketlerine düşülür. Site yapısı değişirse
// PLATFORM_SELECTORS bloğunu güncelle.

import * as cheerio from 'https://esm.sh/cheerio@1.0.0';

export interface ScrapeResult {
  name: string;
  price: number | null;
  image_url?: string;
  currency: string;
  platform: string;
}

const USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0',
];

function randomUA(): string {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

function detectPlatform(url: string): string {
  const u = url.toLowerCase();
  if (u.includes('trendyol.com') || u.includes('tycdn.com')) return 'Trendyol';
  if (u.includes('n11.com')) return 'n11';
  if (u.includes('hepsiburada.com')) return 'Hepsiburada';
  if (u.includes('amazon.')) return 'Amazon';
  if (u.includes('ciceksepeti.com')) return 'ÇiçekSepeti';
  return 'Diğer';
}

// Platform'a özel fiyat seçicileri (denenen sırayla).
const PLATFORM_SELECTORS: Record<string, string[]> = {
  Trendyol: ['.prc-dsc', '.prc-slg', '[data-testid="product-price"]', '.product-price'],
  n11: ['.newPrice', '.price', '.productPrice', '.unf-p-summary-price'],
  Hepsiburada: ['[data-test-id="price"]', '.price', '.product-price'],
  Amazon: ['.a-price .a-offscreen', '#priceblock_ourprice', '#priceblock_dealprice'],
  'ÇiçekSepeti': ['.price', '.product-price', '.prc'],
};

function parsePrice(raw: string | undefined | null): number | null {
  if (!raw) return null;
  // Sadece sayı, nokta ve virgül bırak.
  let t = raw.replace(/[^\d.,]/g, '').trim();
  if (!t) return null;

  const lastComma = t.lastIndexOf(',');
  const lastDot = t.lastIndexOf('.');
  if (lastComma > -1 && lastDot > -1) {
    // Türkçe format (1.234,56): virgül en sonda ise ondalık ayraç.
    t = lastComma > lastDot
      ? t.replace(/\./g, '').replace(',', '.')
      : t.replace(/,/g, '');
  } else if (lastComma > -1) {
    // Tek virgül varsa ondalık say.
    t = t.replace(',', '.');
  }

  const value = parseFloat(t);
  return Number.isNaN(value) ? null : value;
}

function meta($: cheerio.CheerioAPI, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const byProp = $(`meta[property="${key}"]`).attr('content');
    if (byProp) return byProp;
    const byName = $(`meta[name="${key}"]`).attr('content');
    if (byName) return byName;
  }
  return undefined;
}

// schema.org JSON-LD içinden Offer/Product fiyatını bulur.
function extractJsonLdPrice(data: unknown): number | null {
  if (Array.isArray(data)) {
    for (const item of data) {
      const p = extractJsonLdPrice(item);
      if (p != null) return p;
    }
    return null;
  }
  if (typeof data !== 'object' || data === null) return null;
  const obj = data as Record<string, unknown>;
  const type = obj['@type'];
  const isType = (t: string) =>
    type === t || (Array.isArray(type) && type.includes(t));

  if (isType('Offer')) {
    const raw = obj.price ?? obj.lowPrice ?? obj.highPrice;
    const p = parsePrice(raw != null ? String(raw) : '');
    if (p != null) return p;
  }
  if (isType('Product')) {
    const p = extractJsonLdPrice(obj.offers);
    if (p != null) return p;
  }
  if ('@graph' in obj) {
    const p = extractJsonLdPrice(obj['@graph']);
    if (p != null) return p;
  }
  return null;
}

function jsonLdPrice($: cheerio.CheerioAPI): number | null {
  for (const node of $('script[type="application/ld+json"]').toArray()) {
    try {
      const parsed = JSON.parse($(node).text());
      const p = extractJsonLdPrice(parsed);
      if (p != null) return p;
    } catch {
      // Bozuk JSON-LD'yi yoksay.
    }
  }
  return null;
}

function extractJsonLdName(data: unknown): string | undefined {
  if (Array.isArray(data)) {
    for (const item of data) {
      const n = extractJsonLdName(item);
      if (n) return n;
    }
    return undefined;
  }
  if (typeof data !== 'object' || data === null) return undefined;
  const obj = data as Record<string, unknown>;
  const type = obj['@type'];
  const isProduct =
    type === 'Product' || (Array.isArray(type) && type.includes('Product'));
  if (isProduct && typeof obj.name === 'string' && obj.name.trim()) {
    return obj.name.trim();
  }
  if ('@graph' in obj) return extractJsonLdName(obj['@graph']);
  return undefined;
}

function jsonLdName($: cheerio.CheerioAPI): string | undefined {
  for (const node of $('script[type="application/ld+json"]').toArray()) {
    try {
      const parsed = JSON.parse($(node).text());
      const n = extractJsonLdName(parsed);
      if (n) return n;
    } catch {
      // yoksay
    }
  }
  return undefined;
}

function browserHeaders(): Record<string, string> {
  return {
    'User-Agent': randomUA(),
    'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
    Accept:
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'cross-site',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    Referer: 'https://www.google.com/',
  };
}

export interface DebugInfo {
  status: number;
  len: number;
  counts: Record<string, number>;
  snippet?: string;
}

// Geliştirme aracı: sayfanın fiyat içeren bölümünü ve anahtar
// kelime sayılarını döndürür. Seçicileri güncellemek için kullanılır.
export async function debugFetch(url: string): Promise<DebugInfo> {
  const res = await fetch(url, { headers: browserHeaders() });
  const html = await res.text();
  const keys = [
    'newPrice',
    'productPrice',
    'prc-dsc',
    '__NEXT_DATA__',
    'window.__INITIAL_STATE__',
    'priceText',
    '"price"',
    'application/ld+json',
  ];
  const counts: Record<string, number> = {};
  for (const k of keys) counts[k] = html.split(k).length - 1;

  let snippet: string | undefined;
  for (const k of ['newPrice', 'productPrice', 'priceText', '"price"']) {
    const i = html.indexOf(k);
    if (i > -1) {
      snippet = html.slice(Math.max(0, i - 300), i + 700);
      break;
    }
  }
  return { status: res.status, len: html.length, counts, snippet };
}

export async function scrapeProduct(url: string): Promise<ScrapeResult> {
  const platform = detectPlatform(url);

  const res = await fetch(url, {
    headers: browserHeaders(),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const html = await res.text();
  const $ = cheerio.load(html);

  // 1) Platform seçicileri.
  let price: number | null = null;
  for (const sel of PLATFORM_SELECTORS[platform] ?? []) {
    const text = $(sel).first().text().trim();
    price = parsePrice(text);
    if (price != null) break;
  }

  // 2) JSON-LD (schema.org) — çoğu pazaryeri fiyatı burada verir.
  if (price == null) {
    price = jsonLdPrice($);
  }

  // 3) OG / meta yedekleri.
  if (price == null) {
    price = parsePrice(
      meta($, 'product:price:amount', 'og:price:amount', 'price') ?? undefined,
    );
  }

  const name =
    (() => {
      for (const node of $('script[type="application/ld+json"]').toArray()) {
        try {
          const parsed = JSON.parse($(node).text());
          const found = jsonLdName(parsed);
          if (found) return found;
        } catch {
          // yoksay
        }
      }
      return undefined;
    })() ??
    meta($, 'og:title', 'twitter:title') ??
    $('title').first().text().trim() ??
    'Ürün';

  const image =
    meta($, 'og:image', 'twitter:image') ??
    $('link[rel="image_src"]').attr('href');

  return {
    name: name.trim(),
    price,
    image_url: image,
    currency: '₺',
    platform,
  };
}
