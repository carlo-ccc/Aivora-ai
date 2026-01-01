# Aivora AI

An open-source, modern-design AI chat app built with Flutter. It runs on mobile and web (some on-device vision features are mobile-only).

- Tech Stack: Flutter · Dart · Riverpod · GoRouter · Dio

## Features

- Auth (local demo): Register / Login / Logout (stored in `shared_preferences`)
- AI Chat: Send/receive messages via OpenAI-compatible `POST /chat/completions`
- Model management: Add multiple model configs (Name / Base URL / API Key) and switch between them
- Drawer + Settings: User entry points and configuration
- Vision (mobile): Pick camera/gallery image and get food labels
  - ML Kit image labeling (`google_mlkit_image_labeling`)
  - On-device TFLite food classifier (`tflite_flutter`) (modal: google/aiy)
  - Optional: use LLM to generate nutrition analysis from labels and (if model supports) image

## Screenshots

- TODO

## Requirements

- Flutter: `3.35.7` (recommended via FVM; see `.fvmrc`)
- Dart: `>=3.9.0 <4.0.0`

## Quick Start

```bat
flutter pub get
flutter run
```

If you use FVM:

```bat
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

- If `Base URL` is empty, requests will fail (the app will prompt you to configure it).

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

## Contributing

Issues and PRs are welcome.

- Keep changes focused and incremental
- Run `flutter analyze` and `flutter test` before submitting

## License

Apache License 2.0. See `LICENSE`.
