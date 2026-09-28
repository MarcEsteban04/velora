# Velora

A friendly, offline-first companion for tracking spending, budgets and goals, guided by Velora the red panda.

## Getting started

```bash
flutter pub get
flutter run
flutter test
```

## Project structure

```
lib/
├── main.dart                 # Entry point
├── app/                      # App shell (MaterialApp, routing)
├── core/                     # Shared across features
│   ├── constants/            # Asset paths, app-wide constants
│   ├── theme/                # Color tokens, typography, ThemeData
│   └── widgets/              # Reusable UI components
└── features/
    └── <feature>/
        └── presentation/     # Screens and feature-specific widgets

assets/
├── fonts/                    # Bundled fonts (Fredoka, Nunito), no network needed
└── images/mascot/            # Velora mascot artwork

test/                         # Mirrors lib/
```

## Design system

- **Palette:** forest greens from the mascot's cap and tee, plus rust and cream from its fur. Every color is defined in `lib/core/theme/app_colors.dart`.
- **Type:** Fredoka for display text and the wordmark, Nunito for everything else.
- **Motion:** every animation respects the OS "reduce motion" setting.
