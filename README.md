# FieldPilot

FieldPilot is a Flutter CRM for medical field sales representatives. Supabase is the active backend for authentication, customers, and visits.

## Current baseline

- Feature-first Flutter structure under `lib/features`
- Riverpod dependency injection
- GoRouter navigation
- Material 3 light and dark themes
- Supabase customer and visit repositories
- Supabase email/password authentication
- Supabase bootstrap controlled by `--dart-define`
- Production screens for auth, dashboard, customers, visits, scanner, map, search, analytics, reminders, and export

## Supabase Configuration

Project:

```text
uljaorybezvnzedjveek
```

The app defaults to:

```text
https://uljaorybezvnzedjveek.supabase.co
```

and the configured Supabase publishable key. You can override them at build time:

```bash
flutter run --dart-define=SUPABASE_PROJECT_ID=uljaorybezvnzedjveek --dart-define=SUPABASE_PUBLISHABLE_KEY=your_publishable_key
```

or:

```bash
flutter run --dart-define=SUPABASE_URL=https://uljaorybezvnzedjveek.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your_publishable_key
```

Run the database schema in Supabase SQL Editor:

```text
supabase/schema.sql
```

Required Supabase products:

- Authentication: Email/Password
- Database tables from `supabase/schema.sql`

Rows are protected by RLS and scoped with `user_id = auth.uid()`.

## Google Maps

Keep the Maps key local by adding it to `android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=your_key_here
```

Use a key from your own Google Cloud project and restrict it to this app/package.
Do not commit public keys copied from another website. Customer address taps open
Google Maps search links, and the Map page shows exact customer coordinates when
saved or approximate governorate markers when only city/governorate is known.

## Next build steps

1. Run `flutter pub get`.
2. Run `supabase/schema.sql` in the Supabase SQL Editor.
3. Enable Supabase email/password auth.
4. Run `flutter analyze` and device builds.
