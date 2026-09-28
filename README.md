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

- **Palette:** leaf green from the mascot's cap, rust and cream from its fur, and a Himalayan dusk (the red panda's home) for the scene colors. Every color is defined in `lib/core/theme/app_colors.dart`.
- **Type:** Fredoka for display text and the wordmark, Nunito for everything else.
- **Motion:** every animation respects the OS "reduce motion" setting.
