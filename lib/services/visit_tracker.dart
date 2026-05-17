// ─────────────────────────────────────────────────────────────────────────────
// VisitTracker — fires once per Dart isolate (i.e. once per app cold start).
// Mirrors the Angular site's visit-tracker.service.ts so the /visits collection
// holds rows from both surfaces, distinguished by the `source` field.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VisitTracker {
  VisitTracker._();
  static bool _fired = false;

  /// One-shot per cold start. Caller can pass `source` to distinguish admin vs
  /// guest mode. Errors are swallowed.
  static Future<void> track({String source = 'flutter'}) async {
    if (_fired) return;
    _fired = true;

    final payload = <String, dynamic>{
      'timestamp': FieldValue.serverTimestamp(),
      'source':    source,
      'platform':  Platform.operatingSystem,           // android / ios / windows / linux / macos
      'osVersion': Platform.operatingSystemVersion,
      'locale':    Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
      'dartVersion': Platform.version.split(' ').first,
      'app': {
        'version':   '1.0.0',
        'flutterDebug': kDebugMode,
        'release':   kReleaseMode,
      },
    };

    // Pull screen + window dimensions from the engine — works on every platform.
    try {
      final v = PlatformDispatcher.instance.views.firstOrNull;
      if (v != null) {
        payload['screen'] = {
          'width':       v.physicalSize.width,
          'height':      v.physicalSize.height,
          'pixelRatio':  v.devicePixelRatio,
        };
      }
    } catch (_) {}

    // Tag with the signed-in admin (if any) for richer analytics.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      payload['adminUid']   = user.uid;
      payload['adminEmail'] = user.email;
    }

    // IP-geo lookup (same free endpoint Angular uses). Best-effort.
    try {
      final r = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        payload.addAll({
          'ip':           j['ip'],
          'ipVersion':    j['version'],
          'city':         j['city'],
          'region':       j['region'],
          'regionCode':   j['region_code'],
          'country':      j['country_name'],
          'countryCode':  j['country_code'],
          'continent':    j['continent_code'],
          'postal':       j['postal'],
          'latitude':     j['latitude'],
          'longitude':    j['longitude'],
          'isp':          j['org'],
          'asn':          j['asn'],
          'currency':     j['currency'],
          'ipapiTimezone': j['timezone'],
        });
      }
    } catch (_) {/* offline / blocked — fine */}

    try {
      await FirebaseFirestore.instance.collection('visits').add(payload);
    } catch (_) {/* rules / offline — fine */}
  }
}
