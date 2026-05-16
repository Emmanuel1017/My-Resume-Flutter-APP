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
| **Admin** | Glass-morphic Firestore controls — availability hero toggle (with pulse animation), contact form / maintenance mode / auto-on switches (each with description), featured message & Kori greeting editors with character counters, live Firestore state preview in monospace |

---

## Architecture

```
lib/
├── main.dart                    # Firebase init, orientation lock, system chrome
├── app.dart                     # MaterialApp + AuthGate (first-run check → routes)
├── firebase_options.dart        # NOT committed — generate via script (see below)
├── theme/
│   └── app_theme.dart           # Navy/green palette matching the portfolio
├── widgets/
│   └── angular_logo.dart        # Angular shield logo (CustomPainter + glow anim)
├── screens/
│   ├── splash_screen.dart       # Orbiting profile photos + Angular logo centre
│   ├── create_admin_screen.dart # First-run: create the admin Firebase Auth user
│   ├── login_screen.dart        # Firebase Auth email/password + forgot password
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
  available_for_work : boolean   ← Available badge on the Angular About section
  contact_open       : boolean   ← Enables/disables the contact form
  maintenance_mode   : boolean   ← Replaces entire Angular site with maintenance page
  featured_message   : string    ← Sticky banner at top of every page (empty = hidden)
  kori_greeting      : string    ← Overrides Kori AI cat's opening bubble text
  auto_on            : boolean   ← Auto-set available_for_work=true when either app opens
}
```

The Angular portfolio reads this document via a real-time `onSnapshot` listener in
`PortfolioSettingsService` (shared across all components). Changes appear on the live
site within ~1 second, no redeploy needed.

---

## Auth flow

### First-time setup
On first launch the app checks Firestore `/portfolio/meta.admin_initialized`:

- `false` (or document missing) → **First-Time Setup** screen → enter email + password → creates Firebase Auth user → marks Firestore flag → navigates to login with credentials pre-filled → auto-proceeds to home
- `true` → goes straight to **Login** screen
- Network error → defaults to Login screen (safe — never shows create-admin if a user already exists)

### Login screen
- **Forgot password** — enter email, tap "Forgot password?" → Firebase sends a reset email
- **No account found** — an inline "Set up the admin account instead →" link appears when the email doesn't match any user

---

## Firebase setup (shared with Angular portfolio)

Both apps share **one Firebase project**. You only set it up once.

### Step 1 — Fill in the Angular `.env`

```bash
cd Angular-Resume
cp .env.example .env   # then open .env and fill in the Firebase section
```

Where to find the values:  
[Firebase Console](https://console.firebase.google.com) → your project → ⚙️ Project Settings → General → **Your apps** → web app → copy the `firebaseConfig` values.

### Step 2 — Generate `firebase_options.dart` (one command)

```bash
cd portfolio-admin
dart scripts/gen_firebase_options.dart
# reads ../Angular-Resume/.env and writes lib/firebase_options.dart
```

If your `.env` is somewhere else:
```bash
dart scripts/gen_firebase_options.dart --env=/path/to/.env
```

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
    match /portfolio/meta {
      allow read, write: if request.auth != null;
    }
    match /contacts/{id} {
      allow create;                          // contact form submissions
      allow read, update, delete: if request.auth != null;
    }
  }
}
```

### Step 4 — Enable Email/Password auth

Console → **Authentication** → Sign-in method → enable **Email/Password**.

### Step 5 — First run: create your admin account in the app

On the very first launch the app shows a **"First-Time Setup"** screen:

1. Enter your email and a password (6+ characters)
2. Tap **Create Admin Account**
3. The app creates a Firebase Auth user, writes `portfolio/meta.admin_initialized = true`, then navigates automatically to the home screen

All future launches go straight to the login screen.

---

## Running locally

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

> **Windows / Claude Code users:** the default pub cache is virtualised. Use:
> ```bash
> PUB_CACHE="$HOME/pub_cache" flutter pub get
> PUB_CACHE="$HOME/pub_cache" flutter run -d <device-id>
> ```
> or the included `run.bat` wrapper which sets this automatically.

---

## Firebase variables reference

All values come from Firebase Console → your project → ⚙️ Project Settings → General → Your apps → web app.

| `.env` key | Where it ends up | Required |
|---|---|---|
| `FIREBASE_API_KEY` | `firebase_options.dart` `apiKey` | ✅ |
| `FIREBASE_AUTH_DOMAIN` | `authDomain` | ✅ |
| `FIREBASE_PROJECT_ID` | `projectId` | ✅ |
| `FIREBASE_STORAGE_BUCKET` | `storageBucket` | ✅ |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` | ✅ |
| `FIREBASE_APP_ID` | `appId` | ✅ |
| `FIREBASE_DATABASE_URL` | `databaseURL` | Optional |
| `FIREBASE_MEASUREMENT_ID` | `measurementId` | Optional |

> **Note:** `firebase_options.dart` and `pubspec.lock` are **gitignored** — run `flutter pub get` after cloning.

---

## Firestore document reference

### `/portfolio/settings` — written by Admin tab, read by Angular site in real-time

| Field | Type | Admin UI control | Angular effect |
|---|---|---|---|
| `available_for_work` | `boolean` | Hero toggle (pulsing dot) | Green/red badge on About photo |
| `contact_open` | `boolean` | Contact Form switch | Enables/disables contact form |
| `maintenance_mode` | `boolean` | Maintenance switch | Full-screen overlay replaces site |
| `featured_message` | `string` | Text field (120 char limit) | Sticky top banner (empty = hidden) |
| `kori_greeting` | `string` | Text field (160 char limit) | Kori's opening chat bubble |
| `auto_on` | `boolean` | Auto On switch | — (write-side only) |

**Auto On behaviour:** when `auto_on = true`, opening the Flutter admin app (`HomeScreen.initState`) or loading the Angular portfolio (`PortfolioSettingsService` first snapshot) automatically writes `available_for_work = true` back to Firestore. Useful when you open either app as a signal that you are active and available.

### `/portfolio/meta` — written by the app on first-run setup

| Field | Type | Purpose |
|---|---|---|
| `admin_initialized` | `boolean` | Prevents the create-admin screen from showing again |
| `admin_uid` | `string` | UID of the Firebase Auth admin user |

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

- The WebView injects CSS on `onPageFinished` to hide the Angular sticky nav; if the Angular site changes its nav selector update `_injectCss` in `portfolio_screen.dart`
- Toggling **Maintenance Mode** in the Admin tab updates Firestore; the Angular site reflects the change in real-time via `PortfolioSettingsService` — no redeploy needed
- For production: run `flutterfire configure` to register a proper native Android/iOS app ID in Firebase and generate `google-services.json`

---

## Related

- **Angular portfolio source** → [github.com/Emmanuel1017/Angular-Resume](https://github.com/Emmanuel1017/Angular-Resume)
- **Live portfolio** → [emmanuel1017.github.io/Angular-Resume](https://emmanuel1017.github.io/Angular-Resume/)
