# Muta

A personal AI assistant built with Flutter: tasks, daily planning and price
tracking across popular e-commerce stores, with push notifications when prices
change.

- **Tasks** – add natural-language tasks; the AI assistant parses date,
  reminders and sub-tasks.
- **Planning** – generate a daily plan from pending tasks and your calendar,
  then drag-free timeline view keeps the day organized.
- **Price tracking** – follow products on Turkish stores (Trendyol, n11,
  Hepsiburada, Amazon, ÇiçekSepeti, Pazarama); set target prices / alerts and
  get localized push notifications when a price drops.
- **Bilingual UI** – English and Turkish.

## Architecture

```
Flutter app (lib/)                Client: Riverpod 3, GoRouter, Supabase SDK
Supabase (supabase/)              Auth, PostgreSQL + RLS (schema.sql), cron (cron.sql)
  ├─ Edge functions               ai (Gemini proxy), scrape-price, search-products, check-prices
  └─ Cron                         Calls check-prices every 3 hours
FCM                               Price alerts and task reminders (device tokens in database)
scraper-worker (own repository)   Optional local price checker with Playwright
```

The Edge Functions are in `supabase/functions/`; the database schema in
`supabase/schema.sql`. Secrets (Gemini API key, FCM service account) live in
Supabase as function secrets — never in the app binary.

## Setup

### 1. Prerequisites

- Flutter SDK (see `.tool-versions` / `pubspec.yaml` environment)
- Node.js (for the Supabase CLI and the optional scraper worker)
- Supabase CLI, Firebase project (for push notifications)

### 2. Supabase backend

1. Create a project at [supabase.com](https://supabase.com).
2. Run `supabase/schema.sql` in the SQL editor (or `supabase db push`).
3. Optionally enable the cron job: edit `<PROJECT_REF>` / `<SERVICE_ROLE_KEY>`
   placeholders in `supabase/cron.sql`, then run it.
4. Deploy functions and set their secrets:

   ```bash
   supabase login
   supabase link --project-ref your-project-ref
   supabase secrets set GEMINI_API_KEY=your_key FCM_SERVICE_ACCOUNT='{"..."...}'
   supabase functions deploy
   ```

### 3. Push notifications (FCM)

1. Create a Firebase project and add an Android app with the package id
   `com.mutalabs.muta` (feel free to change the id in `android/app/build.gradle.kts`).
2. Copy `android/app/google-services.json.example` to
   `android/app/google-services.json` after downloading your real config
   (the file is gitignored by design).

### 4. Configure the app

Copy `env.json.example` to `env.json` (gitignored) and fill in your Supabase
URL and publishable key, then:

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

Building without the defines still compiles; the app shows its "setup
required" screen until values are provided.

### 5. Price checker worker (optional)

The Playwright-based worker that mirrors prices into Supabase lives in its own
repository. It reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the
environment — see the workflow example in `scraper-worker/.github/workflows/`.
Trendyol blocks GitHub runner IPs, so for reliable results run it on your own
machine or a paid residential proxy.

Run it locally:

```bash
cd scraper-worker
npm install
npx playwright install chromium
SUPABASE_URL=https://your-ref.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node index.mjs
```

## Testing

```bash
flutter analyze
flutter test
```

## License

[MIT](LICENSE)
