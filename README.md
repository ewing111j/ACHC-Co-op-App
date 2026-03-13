# ACHC Hub - Homeschool Co-op Mobile App

A full-featured mobile application for the ACHC Homeschool Co-op community, built with Flutter and Firebase.

## Features

### Role-Based Access Control
- **Parent**: Full access to all features
- **Kid/Student**: Assignments only (filtered view)
- **Admin**: Full access + Admin Dashboard

### Core Modules
| Feature | Description |
|---------|-------------|
| 📚 **Assignments** | Sync from Moodle LMS via REST API + manual assignment creation |
| 💬 **Messages** | Real-time chat between co-op members |
| 📅 **Calendar** | Family & co-op event scheduling |
| 📷 **Photos** | Photo gallery for co-op memories |
| ✅ **Check-In** | Daily attendance tracking |
| 📁 **Files** | Shared document repository |
| 📰 **Feeds** | Co-op announcements and news |

### Authentication
- Email/password for Parents and Admins
- **Kid Login**: Parent email + kid name + kid password (no email required for kids!)
- Firebase Authentication with family grouping

## Tech Stack

- **Frontend**: Flutter 3.35.4 (Dart)
- **Backend**: Firebase (Firestore, Auth, Storage, FCM)
- **LMS Integration**: Moodle REST API
- **State Management**: Provider
- **Architecture**: Service-based (no excessive boilerplate)

## Getting Started

### Prerequisites
- Flutter 3.35.4+
- Firebase project (see [Firebase Setup](#firebase-setup))
- Moodle instance (optional, for assignment sync)

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Email/Password Authentication**
3. Create a **Firestore Database**
4. Enable **Firebase Storage**
5. Download `google-services.json` → place in `android/app/`
6. Update `lib/firebase_options.dart` with your project credentials

### Running the App

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build web preview
flutter build web --release

# Build Android APK
flutter build apk --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point + Firebase init
├── firebase_options.dart     # Multi-platform Firebase config
├── models/                   # Data models
│   ├── user_model.dart
│   ├── assignment_model.dart
│   ├── message_model.dart
│   ├── event_model.dart
│   ├── photo_model.dart
│   ├── feed_model.dart
│   └── checkin_model.dart
├── services/                 # Business logic layer
│   ├── auth_service.dart     # Firebase Auth
│   ├── firestore_service.dart # Firestore CRUD
│   ├── moodle_service.dart   # Moodle REST API
│   └── storage_service.dart  # Firebase Storage
├── providers/
│   └── auth_provider.dart    # Auth state management
├── screens/
│   ├── auth/                 # Login & Registration
│   ├── home/                 # Home screen with icon grid
│   ├── assignments/          # Assignment management
│   ├── messages/             # Real-time chat
│   ├── calendar/             # Event calendar
│   ├── photos/               # Photo gallery
│   ├── checkin/              # Attendance tracking
│   ├── files/                # File management
│   ├── feeds/                # Announcements
│   ├── admin/                # Admin dashboard
│   ├── settings/             # User settings & family management
│   └── moodle/               # Moodle integration setup
└── utils/
    ├── app_theme.dart        # App-wide theme (Teal & Orange)
    └── constants.dart        # App constants
```

## Moodle Integration

To sync assignments from your Moodle LMS:

1. Open the app → Assignments → Setup Moodle (gear icon)
2. Enter your **Moodle Site URL** (e.g., `https://school.moodlecloud.com`)
3. Enter your **Moodle API Token**:
   - Log in to Moodle → Profile → Preferences → Security Keys
   - Copy the "Mobile service" key
4. Click "Test Connection" then "Save"
5. Use the Sync button (↻) on the Assignments screen

## Firebase Security Rules

Apply these Firestore rules for development:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Family Account Structure

```
Parent Account (parent@email.com)
  ├── Kid: Emma   (login: parent@email.com + "Emma" + password)
  ├── Kid: Jake   (login: parent@email.com + "Jake" + password)
  └── Kid: Lily   (login: parent@email.com + "Lily" + password)
```

Parents add kids through **Settings → Add Kid Account**.

## License

© 2024 ACHC Homeschool Co-op. All rights reserved.
