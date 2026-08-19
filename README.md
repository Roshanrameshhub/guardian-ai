# Guardian AI

Production-ready Flutter client for the **Guardian AI Safety Suite**, rebuilt from the Google Stitch export.

## Screens

- Login
- Sign Up
- Home Dashboard
- Safety Map (Google Maps)
- Guardian Mode
- Activity
- Profile / Account
- Notifications

## Architecture

Clean Architecture with:

- `lib/core` — theme, widgets, network, routing
- `lib/domain` — entities + repository contracts
- `lib/data` — DTOs + repository implementations
- `lib/mock/mock_data.dart` — **single mock source of truth**
- `lib/features/*` — feature modules (presentation)

## Backend integration

1. Set `ApiConstants.baseUrl` in `lib/core/constants/api_constants.dart`
2. Replace repository implementations in `lib/data/repositories/`
3. Delete `lib/mock/mock_data.dart`

UI and controllers should not need changes.

## Run

```bash
flutter pub get
flutter run
```

Configure Google Maps API keys in:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/AppDelegate.swift` / `Info.plist`
