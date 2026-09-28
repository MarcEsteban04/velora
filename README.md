# Velora

A friendly, offline-first companion for tracking spending, budgets and goals, guided by Velora the red panda.

## Getting started

```bash
flutter pub get
dart run build_runner build   # generates the drift database code
flutter run
flutter test
```

> **Windows:** plugins need symlink support. Turn on Developer Mode once
> (`start ms-settings:developers`).

## Architecture

- **State:** [Riverpod](https://riverpod.dev). Providers sit next to the code they expose.
- **Storage:** offline-first. Records (accounts, and later transactions) go in SQLite via [drift](https://drift.simonbinder.eu). The profile and settings go in `shared_preferences`.
- **Money:** always an `int` count of minor units (cents), never a `double`. See `lib/core/money/`.
- **Secrets:** `.env*` files are git-ignored. Only the Supabase URL and publishable key may ever ship in the app. AI provider keys and the service-role key belong in Supabase Edge Function secrets.

```
lib/
├── main.dart                  # Entry point (loads prefs, starts ProviderScope)
├── app/                       # App shell: theme, first route
├── core/
│   ├── constants/             # Asset paths
│   ├── database/              # drift database (+ generated .g.dart)
│   ├── money/                 # Currency list, formatting, amount input
│   ├── storage/               # SharedPreferences provider
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

test/                          # Mirrors lib/
```

Features so far: `welcome`, `onboarding` (8 steps), `profile`, `accounts`, `home`.

## Design system

- **Palette:** leaf green from the mascot's cap, rust and cream from its fur, and a Himalayan dusk (the red panda's home) for the scene colors. Every color is defined in `lib/core/theme/app_colors.dart`.
- **Type:** Fredoka for display text and the wordmark, Nunito for everything else.
- **Motion:** every animation respects the OS "reduce motion" setting.
