# Superbass - Push Notification System

A complete push notification system using Flutter, React, Supabase, and Firebase Cloud Messaging (FCM).

**Author:** [md-shadat-hossain](https://github.com/md-shadat-hossain)

---

## Overview

This project demonstrates a full push notification implementation where:
- **Flutter mobile app** receives push notifications with sound
- **React admin panel** sends notifications to all registered devices
- **Supabase** stores FCM tokens and notification history
- **Firebase Cloud Messaging** handles notification delivery

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│    Supabase     │◀────│  React Admin    │
│  (Receives PN)  │     │  (FCM Tokens)   │     │  (Sends PN)     │
└────────┬────────┘     └─────────────────┘     └────────┬────────┘
         │                                               │
         │              ┌─────────────────┐              │
         └─────────────▶│     Firebase    │◀─────────────┘
                        │      (FCM)      │
                        └─────────────────┘
```

## Project Structure

```
Superbass/
├── mobile/                     # Flutter mobile app
│   ├── lib/
│   │   └── main.dart          # Main app code
│   ├── android/
│   │   └── app/
│   │       ├── build.gradle.kts
│   │       ├── google-services.json  (add your own)
│   │       └── src/main/AndroidManifest.xml
│   ├── ios/
│   │   └── Runner/
│   │       ├── Info.plist
│   │       └── GoogleService-Info.plist  (add your own)
│   └── pubspec.yaml
│
├── admin/                      # React admin panel
│   ├── src/
│   │   ├── App.tsx            # Admin UI
│   │   └── main.tsx           # Entry point
│   ├── server.js              # Express server with Firebase Admin SDK
│   ├── package.json
│   ├── vite.config.ts
│   ├── .env                   (add your own)
│   └── .env.example
│
├── supabase_schema.sql        # Database schema
└── README.md
```

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.9+)
- [Node.js](https://nodejs.org/) (18+)
- [Firebase Account](https://console.firebase.google.com/)
- [Supabase Account](https://supabase.com/)
- Android Studio / Xcode (for mobile development)

---

## Setup Instructions

### 1. Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Add Android app:
   - Package name: `com.funnycat.funnycat` (or your package name)
   - Download `google-services.json`
   - Place in `mobile/android/app/`
4. Add iOS app:
   - Bundle ID: `com.funnycat.funnycat` (or your bundle ID)
   - Download `GoogleService-Info.plist`
   - Place in `mobile/ios/Runner/`
5. Get Firebase Admin SDK credentials:
   - Go to Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save the JSON file (you'll need values from it)

#### Add SHA-1 Fingerprint (Required for Android)

```bash
cd mobile/android
./gradlew signingReport
```

Copy the SHA-1 fingerprint and add it to Firebase Console → Project Settings → Your Android app → Add fingerprint.

### 2. Supabase Setup

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Create a new project
3. Go to SQL Editor and run the following queries:

**Create fcm_tokens table:**
```sql
CREATE TABLE fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON fcm_tokens
  FOR ALL USING (true) WITH CHECK (true);
```

**Create notifications table:**
```sql
CREATE TABLE notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all" ON notifications
  FOR ALL USING (true) WITH CHECK (true);
```

**Create notification_recipients table:**
```sql
CREATE TABLE notification_recipients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  status TEXT DEFAULT 'sent',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE notification_recipients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all" ON notification_recipients
  FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX idx_notification_recipients_token ON notification_recipients(fcm_token);
```

4. Note your credentials from Project Settings → API:
   - Project URL
   - Anon/Public Key
   - Service Role Key (secret)

### 3. Configure Flutter App

Edit `mobile/lib/main.dart` and update these constants:

```dart
const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 4. Configure Admin Panel

Create `admin/.env` file:

```env
# Supabase
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_SERVICE_KEY=eyJ...your-service-role-key...

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**Note:** Get the Firebase values from the JSON file downloaded in step 1.5.

---

## Running the Project

### Admin Panel

```bash
cd admin
npm install
npm run dev
```

This starts:
- React frontend at http://localhost:5173
- Express server at http://localhost:3001

### Flutter App

```bash
cd mobile
flutter pub get
flutter run
```

Select your device/emulator when prompted.

---

## Usage

### Register a Device

1. Open the Flutter app on your device
2. Allow notification permissions when prompted
3. Click **"Register"** button to save the FCM token to Supabase

### Send a Notification

1. Open admin panel at http://localhost:5173
2. You should see your registered device(s)
3. Enter notification title and body
4. Click **"Send to X device(s)"**

### View Notification History

1. In the Flutter app, click **"Refresh"** button
2. All received notifications are displayed with:
   - Title and body
   - Timestamp
   - Delivery status (green = sent, red = failed)

---

## Database Schema

### fcm_tokens
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| token | TEXT | FCM device token |
| platform | TEXT | 'android' or 'ios' |
| created_at | TIMESTAMP | When token was registered |
| updated_at | TIMESTAMP | Last update time |

### notifications
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| title | TEXT | Notification title |
| body | TEXT | Notification body |
| sent_at | TIMESTAMP | When notification was sent |
| created_at | TIMESTAMP | Creation time |

### notification_recipients
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| notification_id | UUID | Foreign key to notifications |
| fcm_token | TEXT | Recipient's FCM token |
| status | TEXT | 'sent' or 'failed' |
| created_at | TIMESTAMP | Creation time |

---

## API Endpoints

### POST /api/send-notification

Send notification to multiple devices.

**Request Body:**
```json
{
  "tokens": ["fcm_token_1", "fcm_token_2"],
  "title": "Notification Title",
  "body": "Notification message"
}
```

**Response:**
```json
{
  "successCount": 2,
  "failureCount": 0,
  "failedTokens": []
}
```

### GET /api/notifications/:token

Get notification history for a specific FCM token.

**Response:**
```json
[
  {
    "id": "uuid",
    "title": "Hello",
    "body": "World",
    "sent_at": "2024-01-01T00:00:00Z",
    "status": "sent"
  }
]
```

---

## Features

- [x] FCM token registration
- [x] Send notifications to all devices
- [x] Notification sound on receive
- [x] Foreground notification handling
- [x] Background notification handling
- [x] Notification history storage
- [x] View notification history per device
- [x] Failed token tracking

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Mobile App | Flutter, Dart |
| Admin Panel | React, TypeScript, Vite |
| Backend | Node.js, Express |
| Database | Supabase (PostgreSQL) |
| Push Notifications | Firebase Cloud Messaging |
| Local Notifications | flutter_local_notifications |

---

## Dependencies

### Flutter (mobile/pubspec.yaml)
- firebase_core
- firebase_messaging
- flutter_local_notifications
- supabase_flutter

### Admin (admin/package.json)
- react
- @supabase/supabase-js
- firebase-admin
- express
- cors
- dotenv

---

## Troubleshooting

### FIS_AUTH_ERROR on Android
Add your app's SHA-1 fingerprint to Firebase Console.

### Notifications not showing on Android 13+
The app requests POST_NOTIFICATIONS permission automatically. Make sure to allow it.

### Token not saving to Supabase
Check your Supabase URL and anon key in `mobile/lib/main.dart`.

### Permission denied when sending notifications
Verify your Firebase Admin SDK credentials in `admin/.env`, especially:
- FIREBASE_PROJECT_ID should match your project (e.g., `my-app-12345`)
- FIREBASE_PRIVATE_KEY should include `\n` for newlines

### Core library desugaring error
This is already configured in `mobile/android/app/build.gradle.kts`.

---

## License

MIT License

---

## Author

**md-shadat-hossain**

- GitHub: [@md-shadat-hossain](https://github.com/md-shadat-hossain)

---

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Acknowledgments

- [Firebase](https://firebase.google.com/) for Cloud Messaging
- [Supabase](https://supabase.com/) for the backend database
- [Flutter](https://flutter.dev/) for the mobile framework
- [React](https://react.dev/) for the admin panel
