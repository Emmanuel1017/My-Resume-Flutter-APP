// ─────────────────────────────────────────────────────────────────────────────
// ChatStore — local, on-device persistence of Kori chat history.
//
// We keep chats out of Firestore on purpose: they're per-device, often
// personal, and the cost of round-tripping every token through the network
// twice (in to OpenRouter, out to Firestore) would be silly. shared_preferences
// is plenty for a text-only chat history — a few hundred chats with a few
// thousand messages each still fits comfortably in SharedPreferences' limits
// (Android: a few MB before write-perf falls off; iOS: similar).
//
// Schema (JSON-encoded into a single SharedPreferences key):
//
//   {
//     "chats": [
//       { "id": "...", "title": "...", "createdAt": <ms>, "updatedAt": <ms>,
//         "messages": [{ "role": "user|assistant", "text": "...", "ts": <ms> }] }
//     ],
//     "activeId": "..." | null
//   }
//
// Writes are debounced through the public methods — each chat-list update or
// message append produces exactly one disk write. SharedPreferences itself is
// already async + queue-backed so this stays smooth even mid-stream.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  String text;
  final int ts; // epoch ms

  ChatMessage({required this.role, required this.text, required this.ts});

  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'text': text,
        'ts':   ts,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: (j['role'] == 'user') ? ChatRole.user : ChatRole.assistant,
        text: (j['text'] ?? '') as String,
        ts:   (j['ts']   ?? 0)  as int,
      );
}

class Chat {
  final String id;
  String title;
  final int createdAt;
  int updatedAt;
  final List<ChatMessage> messages;

  Chat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id':        id,
        'title':     title,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'messages':  messages.map((m) => m.toJson()).toList(),
      };

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id:        (j['id']        ?? '') as String,
        title:     (j['title']     ?? 'New chat') as String,
        createdAt: (j['createdAt'] ?? 0) as int,
        updatedAt: (j['updatedAt'] ?? 0) as int,
        messages: ((j['messages'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList(),
      );
}

/// Singleton-ish store. `load()` is idempotent; later calls reuse cached state.
class ChatStore {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  static const _kStorageKey = 'kori_chats_v1';

  List<Chat>     _chats     = [];
  String?        _activeId;
  bool           _loaded    = false;
  SharedPreferences? _prefs;

  /// Stream of state changes — UI re-renders on every mutation. Broadcasting
  /// is fine because we never expect many subscribers (one Kori tab at a time)
  /// and missing an event would be worse than re-firing.
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  List<Chat> get chats     => List.unmodifiable(_chats);
  String?    get activeId  => _activeId;
  Chat?      get activeChat =>
      _activeId == null ? null : _chats.firstWhere(
          (c) => c.id == _activeId,
          orElse: () => _chats.isNotEmpty ? _chats.first : _emptyPlaceholder());

  Chat _emptyPlaceholder() => Chat(
        id: '_empty', title: '_empty',
        createdAt: 0, updatedAt: 0, messages: const []);

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final obj = jsonDecode(raw) as Map<String, dynamic>;
        _chats = ((obj['chats'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Chat.fromJson)
            .toList();
        _activeId = obj['activeId'] as String?;
      } catch (_) {
        // Corrupted blob — wipe and start fresh rather than crash.
        _chats = [];
        _activeId = null;
      }
    }
    // Always sort by most recently updated so the list reads chronologically.
    _chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _loaded = true;
    _changes.add(null);
  }

  Future<void> _persist() async {
    if (_prefs == null) return;
    final payload = {
      'chats':    _chats.map((c) => c.toJson()).toList(),
      'activeId': _activeId,
    };
    await _prefs!.setString(_kStorageKey, jsonEncode(payload));
  }

  /// Returns the newly created chat. Activates it.
  Future<Chat> createChat({String title = 'New chat'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final chat = Chat(
      id:        _newId(),
      title:     title,
      createdAt: now,
      updatedAt: now,
      messages:  [],
    );
    _chats.insert(0, chat);
    _activeId = chat.id;
    await _persist();
    _changes.add(null);
    return chat;
  }

  Future<void> selectChat(String id) async {
    if (!_chats.any((c) => c.id == id)) return;
    _activeId = id;
    await _persist();
    _changes.add(null);
  }

  Future<void> deleteChat(String id) async {
    _chats.removeWhere((c) => c.id == id);
    if (_activeId == id) _activeId = _chats.isEmpty ? null : _chats.first.id;
    await _persist();
    _changes.add(null);
  }

  Future<void> renameChat(String id, String title) async {
    final c = _chats.firstWhere((c) => c.id == id, orElse: _emptyPlaceholder);
    if (c.id == '_empty') return;
    c.title = title.trim().isEmpty ? 'Untitled chat' : title.trim();
    c.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _persist();
    _changes.add(null);
  }

  Future<void> clearAll() async {
    _chats.clear();
    _activeId = null;
    await _persist();
    _changes.add(null);
  }

  /// Appends a new message to the active chat. If there is no active chat one
  /// is created. The caller gets back the message object so it can mutate
  /// `.text` during streaming (no extra writes — `updateActiveMessage` saves
  /// when the stream completes).
  Future<ChatMessage> appendMessage(ChatRole role, String text) async {
    var chat = activeChat;
    if (chat == null || chat.id == '_empty') {
      chat = await createChat();
    }
    final msg = ChatMessage(
      role: role,
      text: text,
      ts:   DateTime.now().millisecondsSinceEpoch,
    );
    chat.messages.add(msg);
    chat.updatedAt = msg.ts;

    // Auto-title from the first user message — feels nicer than "New chat"
    // forever, and matches how every other chat app does it.
    if (chat.title == 'New chat' && role == ChatRole.user) {
      chat.title = _autoTitle(text);
    }

    // Keep list sorted by recency.
    _chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    _changes.add(null);
    return msg;
  }

  /// Persist a streaming update on the last message. Throttle by hand —
  /// disk every 600 ms is plenty for "if the app crashes mid-stream the
  /// last few words live on".
  DateTime _lastStreamFlush = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> flushStreamingMessage({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastStreamFlush).inMilliseconds < 600) return;
    _lastStreamFlush = now;
    await _persist();
    // No `_changes.add` here — the in-memory mutation in the screen already
    // triggered setState. Persistence is silent.
  }

  // Take the first ~40 chars of the user's message and clean it up.
  String _autoTitle(String s) {
    final trimmed = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 37)}…';
  }

  String _newId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = Random.secure().nextInt(1 << 32).toRadixString(36);
    return 'c_${ts}_$rand';
  }
}
