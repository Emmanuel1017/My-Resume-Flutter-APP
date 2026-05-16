# portfolio-admin

> Mobile admin panel + portfolio viewer for [Emmanuel1017/Angular-Resume](https://github.com/Emmanuel1017/Angular-Resume).

Built with Flutter. Runs on **iOS** and **Android**.  
Connects to the same Firebase project as the Angular portfolio site.

---

## Screens

| Tab | Description |
|-----|-------------|
| **Portfolio** | WebView of the live site (`emmanuel1017.github.io/Angular-Resume`) with a native URL bar, animated section-jump pill strip, and JS injection that hides the Angular navbar so the experience feels fully native |
| **Profile** | Native Flutter CV — parallax 3-D name letters, auto-cycling skill tabs (6 groups, same colours as the site), tap-to-expand experience timeline, education card, certifications |
| **Admin** | Real-time Firestore controls — availability hero toggle, contact form & maintenance mode switches, featured message and Kori greeting text editors, live preview of current Firestore state |

---

## Architecture

```
lib/
├── main.dart                    # Firebase init, orientation lock, system chrome
├── app.dart                     # MaterialApp + AuthGate (auth stream → routes)
├── firebase_options.dart        # NOT committed — generate with flutterfire CLI
├── theme/
│   └── app_theme.dart           # Navy/green palette matching the portfolio
├── screens/
│   ├── splash_screen.dart       # Orbiting profile photos + progress bar
│   ├── login_screen.dart        # Firebase Auth email/password
│   ├── home_screen.dart         # IndexedStack shell + animated bottom nav
│   ├── portfolio_screen.dart    # WebView + native chrome + JS section bridge
│   ├── profile_screen.dart      # Native CV (all CV data lives here)
│   └── dashboard_screen.dart    # Firestore admin controls
└── services/
    └── portfolio_service.dart   # Reads/writes /portfolio/settings in Firestore
```

**Firestore document written by this app:**

```
/portfolio/settings  {
  available_for_work : boolean   ← reflected instantly on the Angular site
  contact_open       : boolean
  maintenance_mode   : boolean
  featured_message   : string
  kori_greeting      : string
}
```

The Angular portfolio reads this document via a real-time `onSnapshot` listener in
`src/app/about/about.component.ts`, so changes appear on the live site within ~1 second.

---

## Connecting to the Angular portfolio's Firebase

Both apps share **one Firebase project**. The `projectId` must match in both.

### Step 1 — Find your project ID

Open `Angular-Resume/.env` (gitignored on that repo):

```
FIREBASE_PROJECT_ID=your-project-id
```

Or: [Firebase Console](https://console.firebase.google.com) → Project Settings → General → **Project ID**.

### Step 2 — Generate `firebase_options.dart`

**Recommended — FlutterFire CLI (automatic):**

```bash
dart pub global activate flutterfire_cli
cd portfolio-admin
flutterfire configure          # select your existing project when prompted
```

This generates `lib/firebase_options.dart` and places `google-services.json` /
`GoogleService-Info.plist` in the right platform folders automatically.

**Manual alternative:**

1. Console → Project Settings → General → **Your apps**
2. Add an **Android** app: package `com.example.portfolio_admin`
3. Add an **iOS** app: bundle ID `com.example.portfolioAdmin`
4. Download `google-services.json` → `android/app/google-services.json`
5. Download `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`
6. Fill in `lib/firebase_options.dart` (template already in the repo)

### Step 3 — Firestore security rules

Console → **Firestore** → **Rules**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /portfolio/settings {
      allow read;                            // Angular portfolio reads publicly
      allow write: if request.auth != null;  // only authenticated admin writes
    }
  }
}
```

### Step 4 — Create your admin account

1. Console → **Authentication** → Sign-in method → enable **Email/Password**
2. Console → **Authentication** → **Users** → **Add user** → enter your email + password

---

## First run

```bash
# 1. Generate the platform folders (only once, won't overwrite lib/)
flutter create . --project-name portfolio_admin

# 2. Android — add internet permission
#    open  android/app/src/main/AndroidManifest.xml
#    paste inside <manifest>:
#    <uses-permission android:name="android.permission.INTERNET"/>
#    also confirm  minSdkVersion 21  in android/app/build.gradle

# 3. Generate firebase_options.dart (see Step 2 above)

# 4. Install dependencies
flutter pub get

# 5. Launch on connected device / simulator
flutter run
```

---

## Keeping CV data in sync

The Profile tab mirrors the Angular About section.  
When you update your CV in the Angular repo (`about.component.ts` — `stats`, `skillGroups`, `timeline`),
update the matching constants at the top of `lib/screens/profile_screen.dart` as well:

| Angular (`about.component.ts`) | Flutter (`profile_screen.dart`) |
|---|---|
| `stats` array | `_stats` const |
| `skillGroups` array | `_skillGroups` const |
| `timeline` array | `_timeline` const |

---

## Notes

- `firebase_options.dart` and `pubspec.lock` are **gitignored** — run `flutter pub get` after cloning
- The WebView injects CSS on `onPageFinished` to hide the Angular sticky nav; if the Angular site changes its nav selector update `_injectCss` in `portfolio_screen.dart`
- Toggling **Available for Work** in the Admin tab updates Firestore; the Angular site reflects the change in real-time via `onSnapshot` — no redeploy needed

---

## Related

- **Angular portfolio source** → [github.com/Emmanuel1017/Angular-Resume](https://github.com/Emmanuel1017/Angular-Resume)
- **Live portfolio** → [emmanuel1017.github.io/Angular-Resume](https://emmanuel1017.github.io/Angular-Resume/)
