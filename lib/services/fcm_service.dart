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
// Token persistence: we write the FCM token to /admin_tokens/{token} on every
// signed-in start AND on onTokenRefresh. Function reads the whole collection
// before sending so token churn is handled implicitly.
// ─────────────────────────────────────────────────────────────────────────────

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

  // Android notification channel — high importance so the heads-up banner
  // appears even on Do-Not-Disturb-Priority devices. Colored with the app's
  // primary accent so the banner reads as part of the app's visual language.
  // Cannot be `const` because AndroidNotificationChannel's `ledColor` field is
  // a non-const-constructible `Color`. `final` static is equivalent for use.
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
    if (_initialized) return;
    _initialized   = true;
    onOpenMessages = onOpen;

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

    // 3. Permission — iOS prompts, Android 13+ also requires runtime request.
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // 4. Foreground stream — paint a local notification ourselves.
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 5. Tapped-while-in-background stream — route to Messages.
    FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpenMessages?.call());

    // 6. Cold-start tap — if the user tapped a notification that launched the
    //    app from terminated, FirebaseMessaging.getInitialMessage() returns it.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Defer one frame so the navigator is ready.
      Future.microtask(() => onOpenMessages?.call());
    }

    // 7. Token persistence — current token + future refreshes.
    await _persistCurrentToken();
    FirebaseMessaging.instance.onTokenRefresh.listen(_persistToken);
  }

  void _handleForeground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    _fln.show(
      n.hashCode,
      n.title ?? 'New message',
      n.body  ?? '',
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
          // Pull the sender name out of the data payload if the function set it,
          // so the heads-up reads "Jane Doe — Subject" not just "New message".
          styleInformation: BigTextStyleInformation(
            n.body ?? '',
            contentTitle: n.title,
            summaryText:  m.data['email'] as String?,
          ),
        ),
        iOS: const DarwinNotificationDetails(presentBanner: true, presentSound: true),
      ),
    );
  }

  // Only signed-in admin devices persist their token. Guests get no push.
  Future<void> _persistCurrentToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _persistToken(token);
  }

  Future<void> _persistToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // guest — skip
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
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] token persist failed: $e');
    }
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
