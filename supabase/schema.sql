-- Muta · Supabase şeması
-- Bu dosyayı Supabase SQL Editor'da çalıştır.
-- NOT: `auth` şeması Supabase tarafından yönetilir, dokunma.

-- =========================================================
-- 1) GÖREVLER
-- =========================================================
create table if not exists public.tasks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  title        text not null,
  description  text not null default '',
  priority     int  not null default 3 check (priority between 1 and 5),
  status       text not null default 'pending',   -- pending | in_progress | completed
  due_date     timestamptz,
  recurrence   text not null default 'none',     -- none | daily | weekly | monthly
  ai_suggestion text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists tasks_user_idx on public.tasks (user_id);

alter table public.tasks enable row level security;

create policy "tasks_select_own" on public.tasks
  for select using (auth.uid () = user_id);
create policy "tasks_insert_own" on public.tasks
  for insert with check (auth.uid () = user_id);
create policy "tasks_update_own" on public.tasks
  for update using (auth.uid () = user_id);
create policy "tasks_delete_own" on public.tasks
  for delete using (auth.uid () = user_id);

-- =========================================================
-- 2) TAKİP EDİLEN ÜRÜNLER
-- =========================================================
create table if not exists public.tracked_products (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  name          text not null,
  url           text not null,
  platform      text not null default 'Diğer',
  current_price double precision,
  target_price  double precision,
  image_url     text,
  category      text,
  is_active     boolean not null default true,
  notify_on_drop boolean not null default true,
  alert_type    text not null default 'target', -- target | drop | percent
  alert_percent double precision,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists tracked_products_user_idx
  on public.tracked_products (user_id);

alter table public.tracked_products enable row level security;

create policy "products_select_own" on public.tracked_products
  for select using (auth.uid () = user_id);
create policy "products_insert_own" on public.tracked_products
  for insert with check (auth.uid () = user_id);
create policy "products_update_own" on public.tracked_products
  for update using (auth.uid () = user_id);
create policy "products_delete_own" on public.tracked_products
  for delete using (auth.uid () = user_id);

-- =========================================================
-- 3) FİYAT GEÇMİŞİ
-- =========================================================
create table if not exists public.price_history (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.tracked_products (id) on delete cascade,
  price       double precision not null,
  recorded_at timestamptz not null default now()
);

create index if not exists price_history_product_idx
  on public.price_history (product_id, recorded_at desc);

alter table public.price_history enable row level security;

create policy "price_history_select_own" on public.price_history
  for select using (
    exists (
      select 1 from public.tracked_products p
      where p.id = price_history.product_id and p.user_id = auth.uid ()
    )
  );
-- Edge Function (service role) yazar; kullanıcı ekleme/silme yapmaz.
create policy "price_history_insert_service" on public.price_history
  for insert with check (true);

-- =========================================================
-- 3b) MAĞAZA FİYAT KARŞILAŞTIRMASI
-- =========================================================
create table if not exists public.product_offers (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.tracked_products (id) on delete cascade,
  platform    text not null,
  url         text not null,
  price       double precision,
  checked_at  timestamptz not null default now(),
  unique (product_id, url)
);

create index if not exists product_offers_product_idx
  on public.product_offers (product_id, price);

alter table public.product_offers enable row level security;

create policy "product_offers_select_own" on public.product_offers
  for select using (
    exists (
      select 1 from public.tracked_products p
      where p.id = product_offers.product_id and p.user_id = auth.uid ()
    )
  );
create policy "product_offers_insert_own" on public.product_offers
  for insert with check (
    exists (
      select 1 from public.tracked_products p
      where p.id = product_offers.product_id and p.user_id = auth.uid ()
    )
  );
create policy "product_offers_update_own" on public.product_offers
  for update using (
    exists (
      select 1 from public.tracked_products p
      where p.id = product_offers.product_id and p.user_id = auth.uid ()
    )
  );
create policy "product_offers_delete_own" on public.product_offers
  for delete using (
    exists (
      select 1 from public.tracked_products p
      where p.id = product_offers.product_id and p.user_id = auth.uid ()
    )
  );

-- =========================================================
-- 3c) ÜRÜN ADIYLA BOT ARAMALARI
-- =========================================================
create table if not exists public.product_searches (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  query         text not null,
  platforms     text[] not null default '{}',
  status        text not null default 'queued',
  error         text,
  created_at    timestamptz not null default now(),
  completed_at  timestamptz
);

create table if not exists public.product_search_results (
  id            uuid primary key default gen_random_uuid(),
  search_id     uuid not null references public.product_searches (id) on delete cascade,
  platform      text not null,
  name          text not null,
  url           text not null,
  price         double precision,
  image_url     text,
  created_at    timestamptz not null default now(),
  unique (search_id, url)
);

alter table public.product_searches enable row level security;
alter table public.product_search_results enable row level security;

create policy "product_searches_own" on public.product_searches
  for all using (auth.uid () = user_id)
  with check (auth.uid () = user_id);
create policy "product_search_results_own" on public.product_search_results
  for select using (
    exists (
      select 1 from public.product_searches s
      where s.id = product_search_results.search_id and s.user_id = auth.uid ()
    )
  );

-- =========================================================
-- 4) TAKVİM ETKİNLİKLERİ
-- =========================================================
create table if not exists public.calendar_events (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  title         text not null,
  description   text,
  start_time    timestamptz not null,
  end_time      timestamptz not null,
  event_type    text not null default 'reminder', -- task | appointment | reminder
  ai_generated  boolean not null default false,
  linked_task_id uuid,
  created_at    timestamptz not null default now()
);

create index if not exists calendar_events_user_idx
  on public.calendar_events (user_id, start_time);

alter table public.calendar_events enable row level security;

create policy "events_select_own" on public.calendar_events
  for select using (auth.uid () = user_id);
create policy "events_insert_own" on public.calendar_events
  for insert with check (auth.uid () = user_id);
create policy "events_update_own" on public.calendar_events
  for update using (auth.uid () = user_id);
create policy "events_delete_own" on public.calendar_events
  for delete using (auth.uid () = user_id);

-- =========================================================
-- 5) BİLDİRİMLER (fiyat aları vb.)
-- =========================================================
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  type       text not null default 'price_alert',
  title      text not null,
  body       text,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

create policy "notifications_select_own" on public.notifications
  for select using (auth.uid () = user_id);
create policy "notifications_update_own" on public.notifications
  for update using (auth.uid () = user_id);
create policy "notifications_insert_service" on public.notifications
  for insert with check (true);

-- =========================================================
-- 6) CİHAZ TOKEN'LARI (FCM push)
-- =========================================================
create table if not exists public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  token      text not null unique,
  platform   text not null default 'android',
  language   text not null default 'en',
  updated_at timestamptz not null default now()
);

alter table public.device_tokens
  add column if not exists language text not null default 'en';

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy "device_tokens_own" on public.device_tokens
  for all to authenticated
  using (auth.uid () = user_id)
  with check (auth.uid () = user_id);

-- Token başka bir hesapta kayıtlıysa bu hesaba taşır (RLS'i aşması gerekir).
drop function if exists public.register_device_token(text, text);

create or replace function public.register_device_token(
  p_token text,
  p_platform text default 'android',
  p_language text default 'en'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid ();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  insert into public.device_tokens (user_id, token, platform, language, updated_at)
  values (
    uid,
    p_token,
    coalesce(p_platform, 'android'),
    case when p_language = 'tr' then 'tr' else 'en' end,
    now()
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        language = excluded.language,
        updated_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public;
grant execute on function public.register_device_token(text, text, text) to authenticated;

-- =========================================================
-- 7) REALTIME
-- =========================================================
-- Bildirimler uygulama açıkken anında düşsün (zil canlı güncellenir).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end $$;
