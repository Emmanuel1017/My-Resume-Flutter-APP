# portfolio-admin

> Mobile admin panel + portfolio viewer for [Emmanuel1017/Angular-Resume](https://github.com/Emmanuel1017/Angular-Resume).

Built with **Flutter**. Runs on **iOS** and **Android**.  
Connects to the same Firebase project as the Angular portfolio site — changes appear on the live site within ~1 second, no redeploy ever needed.

---

## Entry Screen — Admin or Guest

On launch, if no user is signed in, the app presents **two bold entry cards**:

| Card | Action |
|------|--------|
| **Admin Login** | Opens email/password form → navigates to full admin home on success |
| **Browse as Guest** | Goes straight to Guest Home — no credentials needed |

---

## Screens

### Guest Mode (3 tabs)
Available without any login — useful for sharing a demo link or letting someone explore the portfolio from the admin perspective.

| Tab | Description |
|-----|-------------|
| **Portfolio** | WebView of the live site, identical to Admin mode |
| **Profile** | Full native CV screen — same as Admin mode |
| **Message** | A contact form that writes directly to Firestore `/contacts` — same endpoint as the Angular contact form. Source is tagged `flutter-guest` so admin can filter by origin. |

### Admin Mode (3 tabs)
| Tab | Description |
|-----|-------------|
| **Portfolio** | WebView of the live site with a native URL bar, animated section-jump pill strip, and JS injection that hides the Angular navbar so the experience feels fully native. Progress indicator and back-navigation are implemented with `ValueNotifier` so the WebView itself is never rebuilt during load or scroll. |
| **Profile** | Native Flutter CV — parallax 3-D name letters, auto-cycling skill tabs (6 groups, same colours as the Angular site), tap-to-expand experience timeline, education card, certifications |
| **Admin** | Glassmorphic Firestore control centre — animated availability hero card (pulsing dot, gradient glow), per-control description labels, char-counted message editors, live Firestore state preview in monospace, sign-out that navigates back to login |

---

## Admin Dashboard — Feature Reference

### Availability Hero
Large tappable card at the top of the Admin tab. Tapping toggles `available_for_work` in Firestore. The card colour, border glow, and dot pulse all animate between green (available) and red (unavailable) with a 500 ms spring.

When **Auto On** is enabled an `⚡ Auto On active` badge appears below the sub-label.

### Site Controls

| Control | Firestore field | Description |
|---|---|---|
| Contact Form | `contact_open` | Allow/block visitors from submitting the contact form. When off, the form is hidden and a themed dark card with a direct email link is shown instead. |
| Maintenance Mode | `maintenance_mode` | Replaces the entire Angular portfolio with a fullscreen maintenance overlay. An amber inline warning appears in the app when this is active so you can't accidentally leave it on. |
| Auto On | `auto_on` | When enabled, either app opening automatically sets `available_for_work = true`. Flutter fires on `HomeScreen.initState`; Angular fires on its first Firestore snapshot. |

### Broadcasts

| Field | Char limit | Effect |
|---|---|---|
| Featured Banner | 120 | A floating glass pill banner appears just below the Angular navbar across every page. Leave blank to hide it. Slides in with a spring animation. |
| Kori's Opening Line | 160 | Overrides Kori's first chat bubble on the portfolio. Leave blank for the default greeting. |

A **Save Changes** button appears (with animated entry) only when either text field is dirty. It shows a spinner during the Firestore write and disappears with a SnackBar confirmation once saved.

### Live State Preview
A monospace card at the bottom shows the current Firestore values exactly as stored (`available_for_work: true`, `auto_on: false`, etc.) with a pulsing dot indicating live/connecting status.

### Messages Inbox
A live-updating list of all contact form submissions from **both** the Angular portfolio and the Flutter guest contact form. Powered by a Firestore `StreamBuilder` on `/contacts` ordered by timestamp descending.

| Feature | Detail |
|---|---|
| **Unread dot** | Green dot on left of sender name for messages with `read: false` |
| **Source badge** | `web` (Angular form) or `app` (Flutter guest) |
| **Expand / collapse** | Tap any message to see the full text |
| **Mark as read** | Automatically marks `read: true` on first open |
| **Reply** | Tap "Copy email to reply" — copies sender's address to clipboard, shows a snackbar confirmation |

---

## Architecture

```
lib/
├── main.dart                    # Firebase init, orientation lock, system chrome
├── app.dart                     # MaterialApp + AuthGate (first-run check → routes)
├── firebase_options.dart        # NOT committed — generate via script (see below)
├── theme/
│   └── app_theme.dart           # Navy/green palette — bg #0D1321, accent #A8E87A
├── widgets/
│   └── angular_logo.dart        # Angular shield logo (CustomPainter + glow anim)
├── screens/
│   ├── splash_screen.dart        # Orbiting profile photos + Angular logo centre
│   ├── create_admin_screen.dart  # First-run: create the Firebase Auth admin user
│   ├── login_screen.dart         # Entry screen: bold Admin / Guest choice, then admin login form
│   ├── home_screen.dart          # Admin IndexedStack shell + animated bottom nav + auto-on trigger
│   ├── guest_home_screen.dart    # Guest IndexedStack shell: Portfolio + Profile + Message tabs
│   ├── guest_contact_screen.dart # Guest contact form → writes /contacts with source=flutter-guest
│   ├── portfolio_screen.dart     # WebView + ValueNotifier chrome + throttled scroll bridge
│   ├── profile_screen.dart       # Native CV (all CV data lives here as const)
│   └── dashboard_screen.dart     # Firestore admin controls + live Messages inbox
└── services/
    └── portfolio_service.dart    # PortfolioSettings model + stream() / save() / toggle()
```

**Firestore document written by this app:**

```
/portfolio/settings  {
  available_for_work : boolean   ← Available badge on the Angular About section
  contact_open       : boolean   ← Enables/disables the contact form
  maintenance_mode   : boolean   ← Replaces entire Angular site with maintenance page
  featured_message   : string    ← Glass pill banner below navbar (empty = hidden)
  kori_greeting      : string    ← Overrides Kori AI cat's opening bubble text
  auto_on            : boolean   ← Auto-set available_for_work=true when either app opens
}
```

The Angular portfolio reads this document via a single real-time `onSnapshot` listener in `PortfolioSettingsService` — a singleton service injected once, shared across all components.

---

## Performance Design

### WebView (`portfolio_screen.dart`)
All mutable UI state uses `ValueNotifier<T>` instead of `setState` so the `WebViewWidget` itself is never rebuilt:

| Notifier | What updates |
|---|---|
| `_progress` | Progress bar only (2 px element) |
| `_loaded` | Loading overlay + reload icon |
| `_canGoBack` | Back-button opacity |
| `_activeSection` | Section pill highlight |
| `_showSections` | Pill strip slide/opacity |

The JS scroll observer is **throttled to 150 ms** via `setTimeout` — reduces platform-channel messages ~10× while scrolling vs firing on every pixel.

### Admin Dashboard (`dashboard_screen.dart`)
`BackdropFilter` (GPU blur) is used for **one element only** — the hero availability card — because it is the focal point and there is exactly one instance on screen. All other cards use `_GlassCard`, which achieves the same frosted look via gradient + border + semi-transparency with zero compositing cost.

Animated elements (`_PulsingDot`, `_LiveDot`) that tick every frame are wrapped in `RepaintBoundary` so their per-frame paints are isolated and don't invalidate parent layers.

All `GoogleFonts` `TextStyle` objects are created once as file-level `final` variables, not on every `build()` call.

---

## Auth Flow

### Entry screen
When no user is signed in the app shows two large bold cards:
- **Admin Login** → reveals the email/password form with a back button
- **Browse as Guest** → navigates directly to `GuestHomeScreen` with no auth required

### First-time admin setup
On first launch (no prior admin) the app checks Firestore `/portfolio/meta.admin_initialized`:

- `false` (or document missing) → **First-Time Setup** screen → enter email + password → creates Firebase Auth user → marks Firestore flag → navigates to login with credentials pre-filled → auto-proceeds to home
- `true` → goes straight to the entry screen (Admin Login / Guest)
- **Network error** → defaults to Login screen (safe — never shows create-admin if a user already exists)

### Admin login form
- **Forgot password** — enter email, tap "Forgot password?" → Firebase sends a reset email
- **No account found** — inline "Set up the admin account instead →" link appears when the email doesn't match any user
- Back arrow returns to the Admin / Guest choice screen

---

## Firebase Setup (shared with Angular portfolio)

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

## Running Locally

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

> **Windows users:** the default pub cache path may be virtualised. Use the included `run.bat` wrapper which sets `PUB_CACHE` to a real filesystem path automatically:
> ```bat
> run.bat run -d <device-id>
> ```
> Or set it manually:
> ```powershell
> $env:PUB_CACHE = "$env:USERPROFILE\pub_cache"
> flutter pub get
> flutter run -d <device-id>
> ```

---

## Firebase Variables Reference

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

## Firestore Document Reference

### `/portfolio/settings` — written by Admin tab, read by Angular site in real-time

| Field | Type | Admin UI control | Angular effect |
|---|---|---|---|
| `available_for_work` | `boolean` | Hero toggle (animated pulsing dot) | Green/red badge on About photo |
| `contact_open` | `boolean` | Contact Form switch | Hides form + shows dark closed-banner with email link |
| `maintenance_mode` | `boolean` | Maintenance switch | Full-screen overlay replaces entire site |
| `featured_message` | `string` | Text field (120 char, char counter) | Glass pill banner below navbar (empty = hidden) |
| `kori_greeting` | `string` | Text field (160 char, char counter) | Kori's opening chat bubble |
| `auto_on` | `boolean` | Auto On switch | Auto-sets `available_for_work = true` on first snapshot |

### Auto On behaviour
When `auto_on = true`:
- **Flutter**: `HomeScreen.initState` reads the first stream emission and calls `toggle('available_for_work', true)` before the first frame renders
- **Angular**: `PortfolioSettingsService` fires `setDoc({ available_for_work: true }, { merge: true })` on its first Firestore snapshot, guarded by a `autoOnFired` flag so it only runs once per page load

### `/portfolio/meta` — written on first-run setup

| Field | Type | Purpose |
|---|---|---|
| `admin_initialized` | `boolean` | Prevents the create-admin screen from showing on subsequent launches |
| `admin_uid` | `string` | UID of the Firebase Auth admin user |

### `/contacts/{id}` — written by Angular contact form + Flutter guest form

| Field | Type | Written by | Description |
|---|---|---|---|
| `name` | `string` | both | Sender's display name |
| `email` | `string` | both | Sender's email address |
| `message` | `string` | both | Full message body |
| `timestamp` | `Timestamp` | both | Server timestamp (used for inbox ordering) |
| `source` | `string` | both | `angular` (from the web form) or `flutter-guest` (from the app) |
| `read` | `boolean` | both | `false` on creation; set to `true` when opened in the admin Messages inbox |

Firestore rules: `allow create` for everyone (public contact form); `allow read, update, delete` only for authenticated admin (so guest users cannot read the inbox, only submit).

---

## Keeping CV Data in Sync

The Profile tab mirrors the Angular About section.  
When you update your CV in the Angular repo (`about.component.ts` — `stats`, `skillGroups`, `timeline`), update the matching constants at the top of `lib/screens/profile_screen.dart`:

| Angular (`about.component.ts`) | Flutter (`profile_screen.dart`) |
|---|---|
| `stats` array | `_stats` const |
| `skillGroups` array | `_skillGroups` const |
| `timeline` array | `_timeline` const |

---

## Notes

- The WebView injects CSS on `onPageFinished` to hide the Angular sticky nav; if the Angular site changes its nav selector update `_injectCss` in `portfolio_screen.dart`
- Toggling **Maintenance Mode** in the Admin tab updates Firestore instantly — the Angular site reflects the change via `PortfolioSettingsService` with no redeploy
- For production: run `flutterfire configure` to register a proper native Android/iOS app ID in Firebase and regenerate `google-services.json` / `GoogleService-Info.plist`
- The `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`, and `test/` directories are not committed — regenerate them with `flutter create . --project-name portfolio_admin`

---

## Related

- **Angular portfolio source** → [github.com/Emmanuel1017/Angular-Resume](https://github.com/Emmanuel1017/Angular-Resume)
- **Live portfolio** → [emmanuel1017.github.io/Angular-Resume](https://emmanuel1017.github.io/Angular-Resume/)
