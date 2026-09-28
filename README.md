# Velora

A friendly companion for tracking spending, budgets and goals, guided by Velora the red panda.

## Getting started

1. **Configure Supabase:** copy `.env.app.example` to `.env.app` and fill in your project URL and **publishable** key.
2. **Create the schema:** run `supabase/migrations/*.sql` in the Supabase SQL Editor, or use `supabase db push`.
3. **Enable anonymous sign-ins:** Dashboard → Authentication → Sign In / Providers → *Allow anonymous sign-ins*.
4. Run it:

```bash
flutter pub get
flutter run --dart-define-from-file=.env.app
flutter test
```

> **Windows:** plugins need symlink support. Turn on Developer Mode once
> (`start ms-settings:developers`).

## Architecture

- **Backend:** [Supabase](https://supabase.com) Postgres is the database. Every table has row-level security, so users only ever see their own rows.
- **Auth:** anonymous sign-in happens silently when onboarding finishes. Linking an email or Google account later keeps the same user id and all their data.
- **Writes that must be all-or-nothing** go through Postgres functions, for example `complete_onboarding`.
- **State:** [Riverpod](https://riverpod.dev). Repositories are providers, so tests swap in in-memory fakes.
- **Money:** always an `int` count of minor units (cents), never a `double`. See `lib/core/money/`.
- **Secrets:** `.env*` files are git-ignored. Only the Supabase URL and publishable key may ever reach the app. AI provider keys and the service-role key belong in Supabase Edge Function secrets.

```
lib/
├── main.dart                  # Entry point (Supabase init, ProviderScope)
├── app/                       # App shell + AppGate (splash / offline / route)
├── core/
│   ├── constants/             # Asset paths
│   ├── money/                 # Currency list, formatting, amount input
│   ├── supabase/              # Config (dart-define) + client provider
│   ├── theme/                 # Color tokens, typography, ThemeData
│   └── widgets/               # Shared UI: buttons, mascot, backdrop, cards
└── features/<feature>/
    ├── domain/                # Plain models
    ├── data/                  # Repositories + providers
    ├── application/           # Controllers (use-case logic)
    └── presentation/          # Screens, steps, widgets

assets/
├── fonts/                     # Bundled Fredoka and Nunito
└── images/mascot/             # Velora poses: wave, coin, wallet, thumbs-up

supabase/migrations/           # Database schema, RLS policies, functions
test/                          # Mirrors lib/
```

Features so far: `welcome`, `onboarding` (8 steps), `auth`, `profile`, `accounts`, `home`.

## Design system

- **Palette:** leaf green from the mascot's cap, rust and cream from its fur, and a Himalayan dusk (the red panda's home) for the scene colors. Every color is defined in `lib/core/theme/app_colors.dart`.
- **Type:** Fredoka for display text and the wordmark, Nunito for everything else.
- **Motion:** every animation respects the OS "reduce motion" setting.
