import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioSettings {
  final bool availableForWork;
  final bool contactOpen;
  final bool maintenanceMode;
  final String featuredMessage;
  final String koriGreeting;
  final bool autoOn;

  const PortfolioSettings({
    this.availableForWork = true,
    this.contactOpen = true,
    this.maintenanceMode = false,
    this.featuredMessage = '',
    this.koriGreeting = '',
    this.autoOn = false,
  });

  factory PortfolioSettings.fromMap(Map<String, dynamic> m) =>
      PortfolioSettings(
        availableForWork: m['available_for_work'] as bool? ?? true,
        contactOpen:      m['contact_open']       as bool? ?? true,
        maintenanceMode:  m['maintenance_mode']   as bool? ?? false,
        featuredMessage:  m['featured_message']   as String? ?? '',
        koriGreeting:     m['kori_greeting']      as String? ?? '',
        autoOn:           m['auto_on']            as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
    'available_for_work': availableForWork,
    'contact_open':       contactOpen,
    'maintenance_mode':   maintenanceMode,
    'featured_message':   featuredMessage,
    'kori_greeting':      koriGreeting,
    'auto_on':            autoOn,
  };

  PortfolioSettings copyWith({
    bool?   availableForWork,
    bool?   contactOpen,
    bool?   maintenanceMode,
    String? featuredMessage,
    String? koriGreeting,
    bool?   autoOn,
  }) => PortfolioSettings(
    availableForWork: availableForWork ?? this.availableForWork,
    contactOpen:      contactOpen      ?? this.contactOpen,
    maintenanceMode:  maintenanceMode  ?? this.maintenanceMode,
    featuredMessage:  featuredMessage  ?? this.featuredMessage,
    koriGreeting:     koriGreeting     ?? this.koriGreeting,
    autoOn:           autoOn           ?? this.autoOn,
  );
}

class PortfolioService {
  static final _doc = FirebaseFirestore.instance
      .collection('portfolio')
      .doc('settings');

  // Session-once gate for the auto-on side effect. HomeScreen + GuestHomeScreen
  // both used to call _triggerAutoOn() in their initState; with the if-tab tab
  // memory model that re-fires every time the user comes back to the app, and
  // every write echoed back through every listener — including the admin's own
  // dashboard, which would visibly flicker the "Available for Work" toggle. We
  // now keep one static flag for the lifetime of the Dart isolate so the
  // side-effect runs at most once per cold start, mirroring Angular's
  // `autoOnFired` gate in PortfolioSettingsService.
  static bool _autoOnFired = false;

  Stream<PortfolioSettings> stream() => _doc.snapshots().map(
    (s) => s.exists
        ? PortfolioSettings.fromMap(s.data()!)
        : const PortfolioSettings(),
  );

  Future<void> save(PortfolioSettings s) =>
      _doc.set(s.toMap(), SetOptions(merge: true));

  Future<void> toggle(String field, bool value) =>
      _doc.set({field: value}, SetOptions(merge: true));

  /// One-shot per app process: if `auto_on` is enabled AND the owner is
  /// currently marked unavailable, flip them to available. Returning early on
  /// "already true" prevents a redundant write that would otherwise fan out
  /// through every listener (and clobber a recent manual toggle-off).
  Future<void> maybeFireAutoOn() async {
    if (_autoOnFired) return;
    _autoOnFired = true;
    try {
      final s = await stream().first;
      if (s.autoOn && !s.availableForWork) {
        await toggle('available_for_work', true);
      }
    } catch (_) {/* offline / no doc yet — fine to skip */}
  }
}
