-- =========================================================
-- Fiyat takibi cron job'u: her 3 saatte bir check-prices çalıştırır.
--
-- Kullanım (iki yol):
--   A) Supabase Dashboard -> Database -> Cron Jobs -> "check-prices"
--      schedule: "0 */3 * * *"  (kolay yol, önerilen)
--   B) Bu dosyayı SQL Editor'da çalıştır (aşağıda).
--
-- Not: SERVICE_ROLE_KEY bir sırdır; repo'da tutma. Üretimde
-- Supabase "Vault" veya pg_cron secret'ı kullan.
-- =========================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Projeniin URL'sini ve service role anahtarını buraya gir.
-- <PROJECT_REF> -> supabase.com dashboard'daki proje ref'i (örn: abcdefghijklmnop)
-- <SERVICE_ROLE_KEY> -> Project Settings -> API -> service_role (secret)
select cron.schedule(
  'check-prices-every-3h',
  '0 */3 * * *',
  $$
    select net.http_post(
      url := 'https://<PROJECT_REF>.supabase.co/functions/v1/check-prices',
      headers := jsonb_build_object(
        'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $$
);

-- İptal etmek istersen:
-- select cron.unschedule('check-prices-every-3h');
