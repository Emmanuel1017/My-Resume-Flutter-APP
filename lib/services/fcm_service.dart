// ─────────────────────────────────────────────────────────────────────────────
// FcmService — push notifications for new contact submissions.
//
// Flow:
//   1.  Angular contact form writes /contacts/{id} to Firestore.
//   2.  Cloud Function (functions/index.js) triggers on that write.
//   3.  Function reads /admin_tokens/{token} docs (only signed-in admin devices
//       save their tokens here — guests never do).
//   4.  Function sends FCM multicast with title/body + data payload.
//   5.  This service handles arrival on the device:
//         • Foreground   → flutter_local_notifications channel
//         • Background   → system tray (Android default handler)
//         • Terminated   → onMessageOpenedApp launches and routes to Messages
//
// Init split:
//   - `init()` runs once from main.dart BEFORE auth: registers the background
//     handler, plumbs the foreground stream, creates the channel.
//   - An auth-state listener inside `init()` watches FirebaseAuth and persists
//     the FCM token to /admin_tokens/{token} every time a user signs in (or
//     deletes it on sign-out). This is the part that used to silently never
//     run — `init()` was called from main.dart before auth, so currentUser was
//     null and the early-return on `_persistCurrentToken()` left the token
//     collection empty forever. HomeScreen could re-call `init()` after login
//     but `_initialized` short-circuited that call too.
//   - Token persistence is now driven by the auth stream so it cannot miss.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background handler — required to be top-level (no closure capture)
// because the OS spawns a fresh isolate for it.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Background work goes here. Right now we let the system tray handle the
  // notification; this hook is reserved for future actions (e.g. preloading
  // the message into local cache before the user opens the app).
  if (kDebugMode) {
    debugPrint('[FCM bg] ${message.messageId}: ${message.notification?.title}');
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _refreshSub;

  // Android notification channel — high importance so the heads-up banner
  // appears even on Do-Not-Disturb-Priority devices. Colored with the app's
  // primary accent so the banner reads as part of the app's visual language.
  static final _androidChannel = AndroidNotificationChannel(
    'portfolio_contacts',
    'New contact messages',
    description: 'Pushed when a visitor submits the portfolio contact form.',
    importance: Importance.high,
    enableVibration: true,
    enableLights:   true,
    ledColor:       const Color.fromARGB(255, 168, 232, 122), // AppColors.accent
    showBadge:      true,
  );

  // Callback invoked when the user taps a notification and the app is in
  // foreground or wakes from background. Wired up in main.dart.
  void Function()? onOpenMessages;

  Future<void> init({void Function()? onOpen}) async {
    // Always refresh the open-callback even on subsequent calls so the latest
    // HomeScreen state is used for routing.
    onOpenMessages = onOpen ?? onOpenMessages;
    if (_initialized) return;
    _initialized = true;

    // 1. Background isolate handler — must be registered before any other FCM
    //    call so the OS knows where to dispatch wake-ups.
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // 2. Local notifications setup so we can render heads-up cards in
    //    foreground (FCM itself doesn't show banners while the app is open).
    await _fln.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS:     DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (_) => onOpenMessages?.call(),
    );
    if (Platform.isAndroid) {
      await _fln
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // 3. Permission — iOS prompts, Android 13+ POST_NOTIFICATIONS prompt is
    //    also requested by FCM under the hood. We log the response so a
    //    silently-denied permission shows up in logcat.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (kDebugMode) {
      debugPrint('[FCM] permission: ${settings.authorizationStatus}');
    }

    // 4. Streams — register before any potential message arrives.
    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpenMessages?.call());

    // 5. Cold-start tap.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      Future.microtask(() => onOpenMessages?.call());
    }

    // 6. Auth-stream driven token persistence. Fires immediately with the
    //    current user (or null), then again on every sign-in / sign-out.
    //    This replaces the previous "best-effort once at init" pattern that
    //    raced auth and silently dropped the token on cold-start.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        // Don't aggressively delete here — `clearTokenOnSignOut()` does an
        // explicit teardown when the user actually taps Sign out. Auth-state
        // null also fires on app launch before the cached session restores,
        // so deleting would race that restore.
        return;
      }
      await _persistTokenForUser(user);
    });

    // 7. Token rotation — Firebase rotates tokens periodically. Save the new
    //    one whenever it arrives.
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await _writeToken(token, user);
    });
  }

  /// Re-runs token persistence for the current user. Safe to call any number
  /// of times — `set` with `merge: true` is idempotent.
  Future<void> ensureTokenSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _persistTokenForUser(user);
  }

  Future<void> _persistTokenForUser(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) debugPrint('[FCM] token (first 12) = ${token?.substring(0, 12)}…');
      if (token == null) return;
      await _writeToken(token, user);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] getToken failed: $e');
    }
  }

  Future<void> _writeToken(String token, User user) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_tokens')
          .doc(token)
          .set({
        'uid':       user.uid,
        'email':     user.email,
        'platform':  Platform.isIOS ? 'ios' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) debugPrint('[FCM] token saved for ${user.email}');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] token write failed: $e');
    }
  }

  void _handleForeground(RemoteMessage m) {
    if (kDebugMode) {
      debugPrint('[FCM fg] ${m.messageId} '
          'notif=${m.notification?.title} data=${m.data}');
    }
    // Many backends send data-only messages on Android to keep delivery
    // priority high. Fall back to the data payload if there's no `notification`.
    final title = m.notification?.title
        ?? (m.data['title'] as String?)
        ?? (m.data['name'] != null ? 'Message from ${m.data['name']}' : null)
        ?? 'New contact message';
    final body = m.notification?.body
        ?? (m.data['body'] as String?)
        ?? (m.data['message'] as String?)
        ?? (m.data['email'] as String?)
        ?? 'Tap to open your inbox';

    _fln.show(
      m.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance:  Importance.high,
          priority:    Priority.high,
          color:       const Color.fromARGB(255, 168, 232, 122),
          colorized:   true,
          icon:        '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText:  m.data['email'] as String?,
          ),
        ),
        iOS: const DarwinNotificationDetails(presentBanner: true, presentSound: true),
      ),
    );
  }

  /// Call on logout so the device stops receiving pushes.
  Future<void> clearTokenOnSignOut() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('admin_tokens').doc(token).delete();
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {/* best effort */}
  }
}
