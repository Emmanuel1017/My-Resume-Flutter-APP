# Portfolio Admin

Flutter app that pairs the [Angular portfolio site](https://emmanuel1017.github.io/Angular-Resume/) with a native admin layer:

- **Portfolio** — embeds the live Angular site in a full-screen WebView with native chrome, momentum scroll, and per-section nav.
- **Kori** — native chat tab. The Angular site's Three.js cat assistant is hidden inside the WebView (saves a Web Worker + WebGL canvas + ~2 MB of JS); Flutter replaces it with a native `CustomPainter` cat + OpenRouter chat client.
- **Profile · Admin · Messages** — live availability toggle, dashboard analytics, paginated inbox with read/unread state, push-notified by Firebase Cloud Messaging.
- **Guest mode** — view portfolio, see profile, send a message (no admin features).

Releases · [v1.0.0 APK](https://github.com/Emmanuel1017/My-Resume-Flutter-APP/releases/latest/download/portfolio-admin.apk)

---

## Architecture

```mermaid
graph TD
    M[main.dart<br/>Firebase · FCM · orientation lock · image cache] --> A{app.dart<br/>Auth stream}

    A -->|signed in| H[HomeScreen — 5 tabs]
    A -->|guest|     G[GuestHomeScreen — 4 tabs]

    H --> H1[Portfolio]
    H --> H2[Kori]
    H --> H3[Profile]
    H --> H4[Admin Console]
    H --> H5[Messages]

    G --> G1[Portfolio]
    G --> G2[Kori]
    G --> G3[Profile]
    G --> G4[Send Message]

    H1 --> WV[WebViewController<br/>UA marker · EagerGestureRecognizer · CSS injection]
    G1 --> WV
    WV -->|loads| ANG[Angular Portfolio<br/>github.io]

    H2 --> KC[KoriCat — CustomPainter]
    H2 --> OR[OpenRouter HTTP · SSE stream]
    G2 --> KC
    G2 --> OR

    H5 --> FS[(Firestore<br/>contacts)]
    H4 --> FS
    H3 --> FS
    G4 --> FS

    FS -->|onDocumentCreated| CF[Cloud Function<br/>notifyAdminsOnNewContact]
    CF --> FCM[FCM multicast]
    FCM -->|push| FCMS[FcmService<br/>foreground / background / terminated]
    FCMS -.deep-link.-> H5

    subgraph Native GPU stack
        IM[Impeller · Vulkan]
        OGL[OpenGL ES 3.0 fallback]
        HZ[120 Hz preferred display mode]
        SP[Sustained performance mode]
    end
```

### Tab memory model

| Tab | Strategy | Reason |
|-----|----------|--------|
| All tabs incl. WebView | `if (_tab == N)` — destroyed on leave | Fully releases GPU surface, Chromium instance, Firestore streams, and chat history on every tab switch. Android HTTP disk cache reloads the Angular site in ~300 ms on return — far cheaper than keeping a live WebView surface pinned in GPU memory. |

---

## What's inside

### 1. Native Kori (replaces Angular's Three.js cat in-app)

The web Kori uses Three.js + a CanvasTexture mackerel-tabby + a Web Worker for in-browser Transformers.js. That's great for the web; it's wrong for a phone. Inside the Flutter WebView the entire `<app-agent>` is hidden via a UA marker:

```dart
_ctrl.setUserAgent('… PortfolioAdminFlutter/1.0 …');
_ctrl.runJavaScript('window.__FLUTTER_APP__ = true; …');
```

Angular checks the flag and skips rendering `<app-agent>` entirely. In its place the app ships a **native chat tab**:

- `lib/widgets/kori_cat.dart` — 2D animated cat in a single `CustomPainter`. Orange-tabby palette mirroring the web cat (`#F4934A` / `#D97A37`), idle breathing (4 s sine), tail wag (2 Hz), independent ear twitches, random blinks every 2.5–5.5 s, forehead M-marking, whiskers, paw highlights. Pupils track an optional `Offset`; tap → "boop" reaction (squish + surprised expression). One `AnimationController` drives the master loop, two short ones for blink + boop — `RepaintBoundary` isolates the whole thing.
- `lib/screens/kori_screen.dart` — OpenRouter HTTP client with **SSE token streaming** parsed straight off the byte stream. System prompt mirrors `agent.service.ts` (Eldoret, distributed-systems Senior SWE, cat persona). Default model = `openai/gpt-4o-mini`, stale-model auto-migration list copied verbatim from the Angular service so users with broken `:free` IDs get bumped to the current default on next open.
- API key resolution mirrors Angular exactly:
  1. User-pasted key from the settings sheet (`shared_preferences`).
  2. Falls back to `openrouter_api_key` from **Firebase Remote Config** (one shared key for all signed-in admins, no per-device setup).
- Cancelable streams, friendly errors (`401 → "invalid key, tap ⚙"`, `429`, `SocketException`).

### 2. FCM end-to-end

| Layer | What it does |
|-------|--------------|
| Angular | Writes `/contacts/{id}` to Firestore on contact-form submit, with `timestamp: serverTimestamp()`, `read: false`, `source: 'web'`. |
| Cloud Function | `functions/index.js` — `onDocumentCreated('contacts/{id}')` reads `/admin_tokens`, sends `sendEachForMulticast` with title/body + data payload (contactId, name, email, source, themed channel/color). Prunes `registration-token-not-registered` tokens in the same invocation. |
| Flutter | `lib/services/fcm_service.dart` registers a top-level background-isolate handler, requests notification permission, hooks `onMessage` / `onMessageOpenedApp` / `getInitialMessage` for foreground / background / cold-start tap respectively. Foreground heads-up rendered via `flutter_local_notifications` with `BigTextStyleInformation` and the app's mint-green accent so it reads as part of the app. Token is saved to `/admin_tokens/{token}` on admin sign-in and deleted on sign-out. Tap → `pendingHomeTab = 4` → HomeScreen jumps to Messages. |

Deploy the function from repo root:

```bash
cd functions && npm install
firebase use --add        # one-time
firebase deploy --only functions:notifyAdminsOnNewContact
```

Requires the Blaze plan. `AndroidManifest.xml` declares `POST_NOTIFICATIONS`, `WAKE_LOCK`, `VIBRATE`, default channel id `portfolio_contacts`, default color `@color/notification_accent` (mint green). `flutter_local_notifications` requires core library desugaring — wired up in `app/build.gradle.kts`.

### 3. Messages — perf-focused inbox

| Win | How |
|-----|-----|
| Legacy 2022 docs now appear | Server-side `orderBy('timestamp')` silently dropped docs without the field. Dropped to plain `.limit(300)` and sort client-side with `Timestamp` → legacy `date` string fallback. |
| Tapping a card doesn't redraw the list | Expansion lives in `ValueNotifier<String?>` (the doc id). Only the two affected cards rebuild. |
| Cards don't bleed paint into each other | Each row is wrapped in its own `RepaintBoundary`. |
| Regex / date parsing doesn't re-run on snapshots | `_MsgRow` wrapper memoizes sort key + read flag; the per-id cache survives across snapshot rebuilds. |
| Initial render stays small | Windowed display (60 rows initial, `+40` per "Load older" tap). Firestore stream still feeds the underlying snapshot in real time. |
| Fast scrolls don't show blank gaps | `cacheExtent: 800` pre-builds a screen-and-a-half. |
| Pull-to-refresh | `RefreshIndicator` resets the window to 60. |
| New actions | "Copy email" + "Mark unread" toggles inside the expanded card. |

### 4. Companion-app integration on the web

Inside the WebView the heavy components stay hidden (UA sniff + JS flag + defensive CSS injection). Outside the WebView (regular browsers) the Angular site gains:

- A sticky orange **promo banner** above the header, dismissible (`localStorage.promoBannerDismissed`), tap-to-scroll to `#app`.
- A pulsing orange **"Get the App"** pill in the nav.
- A **`<app-screenshots>`** section with a 12-shot phone-mockup carousel + Download APK / View source CTAs.

---

## Performance decisions

### Android GPU
- **Impeller / Vulkan** (`EnableImpeller=true` in manifest) — pre-compiles all shaders at launch, eliminating JIT shader jank during scroll and animation. Automatic OpenGL ES 3.0 fallback on older SOCs.
- **Sustained performance mode** (`setSustainedPerformanceMode(true)`) — holds clocks at a thermally stable level, preventing the boost → overheat → throttle → jank cycle on mid/low-end devices.
- **120 Hz** — `preferredDisplayModeId` set to highest available refresh in `onResume`; `allow_multiple_resumed_activities=true` enables variable refresh scheduling on Android 11+.

### WebView scroll
- `EagerGestureRecognizer` on `WebViewWidget` removes the ~80 ms Flutter gesture-arena delay before scroll starts.
- CSS injection overrides `scroll-behavior: auto` (kills Angular router smooth-scroll fighting momentum); `transform: translateZ(0)` on `body` promotes the scroll container to its own GPU compositor layer.
- `content-visibility: auto` on Angular sections skips off-screen paint; `contain: layout style` on cards isolates reflows so one card's resize can't cascade.
- Defensive `display: none !important` on `app-agent`, `.screenshots-section`, `.promo-banner`, `.get-app-cta` — heavy components that have native counterparts in the app shouldn't render at all in-WebView.

### Flutter widget tree
- All dynamic state flows through `ValueNotifier` — the `WebViewWidget` never rebuilds; only the 2 px progress bar or unread badge re-renders.
- `RepaintBoundary` around bottom nav, top chrome, each Kori cat, and each message card.
- `MarqueeLabel` measures text off-layout via `TextPainter`, drives scroll with `AnimatedBuilder` + hoisted child — only the `Transform` node repaints per frame.
- Kori chat history is in-memory only; tab teardown clears the stream subscription, the HTTP client, the controller, and the cat's `AnimationController`s.

### Release build
- R8 full mode (`android.enableR8.fullMode=true`) with `isMinifyEnabled` + `isShrinkResources` — whole-program dead-code elimination across Flutter, Firebase, and FCM/messaging.
- Core library desugaring (`coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`) — required by `flutter_local_notifications`; back-ports `java.time` onto older Android.
- ABI filter: `arm64-v8a` + `armeabi-v7a` only — ~30 % smaller APK, no x86 overhead on real devices.
- Parallel Gradle (`org.gradle.parallel=true`) + build caching.

---

## Project structure

```
lib/
├── main.dart                       Firebase + FCM init, orientation lock, image cache,
│                                   navigatorKey + pendingHomeTab for FCM deep-links
├── app.dart                        Auth stream → HomeScreen / GuestHomeScreen router
├── theme/app_theme.dart            Design tokens
├── services/
│   ├── portfolio_service.dart      Firestore read/write (availability toggle, autoOn)
│   └── fcm_service.dart            Token persistence, foreground heads-up, deep-link routing
├── screens/
│   ├── home_screen.dart            Admin shell: 5-tab nav, unread-count stream, FCM tab consumer
│   ├── guest_home_screen.dart      Guest shell: 4-tab nav
│   ├── portfolio_screen.dart       Full-screen WebView · UA marker · CSS injection · section nav
│   ├── kori_screen.dart            Native chat tab — OpenRouter SSE, Remote Config key
│   ├── profile_screen.dart         Avatar, bio, availability toggle
│   ├── dashboard_screen.dart       Analytics + admin controls + sign-out (clears FCM token)
│   ├── messages_screen.dart        Paginated inbox · _MsgRow memo · ValueNotifier expansion
│   ├── guest_contact_screen.dart   Visitor message form → Firestore
│   └── splash_screen.dart, login_screen.dart, create_admin_screen.dart
└── widgets/
    ├── kori_cat.dart               2D animated cat — CustomPainter, blink/wag/breath/boop
    └── marquee_label.dart          Auto-scrolling nav label (TextPainter + AnimatedBuilder)

functions/
├── index.js                        notifyAdminsOnNewContact — FCM fan-out + stale-token prune
├── package.json                    firebase-admin + firebase-functions v6
└── README.md                       Deploy + emulator instructions

android/
├── app/build.gradle.kts            R8, ABI filter, ProGuard, coreLibraryDesugaring
├── app/proguard-rules.pro          Keep rules: Flutter / Firebase / WebView JS bridge
├── gradle.properties               parallel, caching, R8 full mode, Kotlin incremental
└── app/src/main/
    ├── AndroidManifest.xml         Impeller, 120 Hz, FCM permissions + default channel + color
    ├── res/values/colors.xml       notification_accent (mint green)
    └── kotlin/.../MainActivity     Sustained perf mode + high-refresh-rate request

ios/ · windows/ · linux/            Platform scaffolds — Firebase config still needed before build
```

---

## Run

```bash
# Install deps + grab Firebase config first
flutter pub get
# Drop google-services.json into android/app/  (not committed — contains creds)

# List connected devices
flutter devices

# Debug — hot reload, no R8
flutter run -d <device-id>

# Release — Impeller + R8 + ABI filters active
flutter run -d <device-id> --release

# Or build APK and side-load
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Deploy the Cloud Function (one-time)

```bash
cd functions
npm install
firebase use --add                                  # pick the right project
firebase deploy --only functions:notifyAdminsOnNewContact
```

After deploy, every new submission to `/contacts/*` will push to every device registered in `/admin_tokens`. Devices register on admin sign-in (`FcmService.init`) and unregister on sign-out (`FcmService.clearTokenOnSignOut`).

---

## Firebase Remote Config keys

| Key | Used by | Notes |
|-----|---------|-------|
| `openrouter_api_key` | Angular Kori + Flutter Kori | Shared OpenRouter key. Leave empty to force per-user keys. |
| `available_for_work` | Angular `PortfolioSettingsService` | Boolean string `'true'` / `'false'`. |

---

> No `google-services.json`, `GoogleService-Info.plist`, or Firebase service account is committed to either repo. Drop them in locally before building.
