import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'firebase_options.dart';

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

  runApp(const PortfolioAdminApp());
}
