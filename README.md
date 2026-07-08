# FieldPilot

FieldPilot is an offline-first Flutter CRM for medical field sales representatives. The local database is treated as the source of truth and Firebase is used for authentication, cloud sync, storage, messaging, and team continuity.

## Current baseline

- Feature-first Flutter structure under `lib/features`
- Riverpod dependency injection
- GoRouter navigation
- Material 3 light and dark themes
- Offline-first customer and visit repositories
- Sync queue with conflict metadata
- Firebase bootstrap controlled by `--dart-define`
- Production screens for auth, dashboard, customers, visits, scanner, map, search, analytics, reminders, and export

## Firebase configuration

The app can run offline without Firebase values. Create one Firebase project and enable:

- Authentication: Email/Password
- Cloud Firestore
- Firebase Storage
- Cloud Messaging

Register these app ids in Firebase:

- Android: `com.fieldpilot.app`
- iOS: `com.fieldpilot.app`

Download the native files into:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

The Android Google Services plugin is applied only when `google-services.json` exists, so local builds still work before the file is downloaded.

Android and iOS initialize Firebase from the native config files. Those files are ignored by Git so real credentials stay local.

For temporary manual initialization, pass:

```bash
flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_AUTH_DOMAIN=... --dart-define=FIREBASE_STORAGE_BUCKET=...
```

Deploy rules with the Firebase CLI:

```bash
firebase deploy --only firestore:rules,storage
```

Firestore sync is scoped under `users/{uid}/customers` and `users/{uid}/visits`.

## Google Maps

Keep the Maps key local by adding it to `android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=your_key_here
```

## Next build steps

1. Replace the in-memory local database adapter with the Isar collection adapter and generated schemas.
2. Run `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs`.
3. Add native Firebase platform files.
4. Run `flutter analyze` and device builds.
