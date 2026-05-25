import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';

/// Global navigator key — lets FCM (which lives outside the widget tree)
/// push routes when a notification is tapped.
final navigatorKey = GlobalKey<NavigatorState>();

/// Set by FCM tap → HomeScreen reads this on next build to deep-link to the
/// Messages tab. Cleared back to null after consumption.
final pendingHomeTab = ValueNotifier<int?>(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Portrait lock ──────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── System UI chrome ───────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                Colors.transparent,
    statusBarIconBrightness:       Brightness.light,
    systemNavigationBarColor:      Color(0xFF0D1321),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── Image cache tuning ─────────────────────────────────────────────────────
  // Default: 1 000 images / 100 MB — far too large for a mobile app that loads
  // a handful of profile photos.  Smaller limits mean the GC collects decoded
  // bitmaps sooner, reducing memory pressure on low-end devices.
  PaintingBinding.instance.imageCache
    ..maximumSize      = 60        // max 60 decoded images held in memory
    ..maximumSizeBytes = 50 << 20; // 50 MB decoded pixel data

  // ── Firebase ───────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── FCM ────────────────────────────────────────────────────────────────────
  // Init runs before runApp so the background isolate handler is registered
  // before any push can arrive. Tapping a notification flips pendingHomeTab to
  // 5 (Messages); HomeScreen consumes that and selects the right tab.
  await FcmService.instance.init(
    onOpen: () {
      pendingHomeTab.value = 5; // Messages tab in admin home
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (_) => false);
    },
  );

  runApp(const PortfolioAdminApp());
}
