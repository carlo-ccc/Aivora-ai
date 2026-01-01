# Aivora AI

An open-source, modern-design AI chat app built with Flutter. It runs on mobile and web (some on-device vision features are mobile-only).

- Tech Stack: Flutter · Dart · Riverpod · GoRouter · Dio
- License: Apache-2.0

## Features

- Auth (local demo): Register / Login / Logout (stored in `shared_preferences`)
- AI Chat: Send/receive messages via OpenAI-compatible `POST /chat/completions`
- Model management: Add multiple model configs (Name / Base URL / API Key) and switch between them
- Drawer + Settings: User entry points and configuration
- Vision (mobile): Pick camera/gallery image and get food labels
  - ML Kit image labeling (`google_mlkit_image_labeling`)
  - On-device TFLite food classifier (`tflite_flutter`)
  - Optional: use LLM to generate nutrition analysis from labels and (if model supports) image

## Screenshots

- TODO

## Requirements

- Flutter: `3.35.7` (recommended via FVM; see `.fvmrc`)
- Dart: `>=3.9.0 <4.0.0`

## Quick Start

```bat
cd e:\selfGit\Aivora-ai
flutter pub get
flutter run
```

If you use FVM:

```bat
cd e:\selfGit\Aivora-ai
fvm install
fvm flutter pub get
fvm flutter run
```

## Configuration (LLM)

This app calls an OpenAI-compatible Chat Completions API.

- Open the app → `Settings`
- Add a model with:
  - `Name`: model id (e.g. `gpt-4o-mini`)
  - `Base URL`: e.g. `https://api.openai.com/v1` (the app auto-appends `/chat/completions`)
  - `API Key`: your token (stored locally in `shared_preferences`)

Notes:
- Do not commit API keys to git.
- If `Base URL` is empty, requests will fail (the app will prompt you to configure it).

## Demo Accounts

- Admin shortcut: username/email `carlo`, password `123456` (see `lib/data/services/auth_service.dart`)
- Register: creates a local user and stores it on-device (no backend)

## Platform Notes

- Web: Core navigation + settings can run, but ML Kit / TFLite features are generally not available on web.
- Mobile (Android/iOS): Vision features work (subject to platform/plugin support).

## Project Structure

```text
lib/
  main.dart
  app.dart
  core/
    router/
    theme/
  data/
    models/
    services/
  domain/
  presentation/
    pages/
      auth/
      chat/
      settings/
    providers/
```

## Common Commands

```bat
flutter analyze
flutter test
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture Overview

- Routing: `go_router` with auth redirect (`lib/core/router/app_router.dart`)
- State: Riverpod
  - `authProvider`: session + login/register/logout (`lib/presentation/providers/auth_provider.dart`)
  - `settingsProvider`: LLM model configs + selection (`lib/presentation/providers/settings_service.dart`)
- Networking: `dio` (`lib/data/services/ai_service.dart`)

## Contributing

Issues and PRs are welcome.

- Keep changes focused and incremental
- Run `flutter analyze` and `flutter test` before submitting

## License

Apache License 2.0. See `LICENSE`.
