// ─────────────────────────────────────────────────────────────────────────────
// Portfolio-admin deploy script.
//
// One command from repo root:
//   dart run tool/deploy.dart
//
// What it does, in order:
//   1. flutter pub get
//   2. flutter build apk --release        (Android)
//   3. flutter build windows --release    (skipped if --android-only)
//   4. flutter build linux --release      (Linux hosts only)
//   5. zips the windows/linux outputs into ./build/dist/
//   6. uploads everything to a new (or existing) GitHub Release on the
//      Emmanuel1017/My-Resume-Flutter-APP repo.
//
// Requirements: a GitHub PAT exported as GITHUB_TOKEN. The script never writes
// it anywhere — it's only read from the environment.
//
// Flags:
//   --tag v1.2.3            Tag name (default: auto-bumped patch of latest tag).
//   --android-only          Skip Windows + Linux builds.
//   --no-upload             Build only, don't talk to GitHub.
//   --notes "release notes" Body for the GitHub Release.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _repo = 'Emmanuel1017/My-Resume-Flutter-APP';

Future<void> main(List<String> args) async {
  final flags = _parseFlags(args);

  _step('flutter pub get');
  await _run('flutter', ['pub', 'get']);

  _step('Android (apk --release)');
  await _run('flutter', ['build', 'apk', '--release']);
  final apk = File('build/app/outputs/flutter-apk/app-release.apk');
  if (!apk.existsSync()) _bail('APK not found at ${apk.path}');

  final artifacts = <File>[apk];

  if (!flags.androidOnly) {
    if (Platform.isWindows) {
      _step('Windows (--release)');
      await _run('flutter', ['build', 'windows', '--release']);
      final winDir = Directory('build/windows/x64/runner/Release');
      if (winDir.existsSync()) {
        final zip = await _zipDir(winDir, 'portfolio-admin-windows-x64.zip');
        artifacts.add(zip);
      }
    } else {
      _note('Windows build skipped (host is ${Platform.operatingSystem}).');
    }
    if (Platform.isLinux) {
      _step('Linux (--release)');
      await _run('flutter', ['build', 'linux', '--release']);
      final lxDir = Directory('build/linux/x64/release/bundle');
      if (lxDir.existsSync()) {
        final tar = await _tarDir(lxDir, 'portfolio-admin-linux-x64.tar.gz');
        artifacts.add(tar);
      }
    } else if (Platform.isMacOS) {
      _step('macOS (--release)');
      await _run('flutter', ['build', 'macos', '--release']);
    } else {
      _note('Linux build skipped (host is ${Platform.operatingSystem}).');
    }
    _note('iOS build requires a macOS host with Xcode + signing — run '
          '`flutter build ipa --release` there manually.');
  }

  if (flags.noUpload) {
    _ok('Built ${artifacts.length} artifact(s). Skipping upload (--no-upload).');
    for (final a in artifacts) print('  • ${a.path}');
    return;
  }

  final token = Platform.environment['GITHUB_TOKEN'];
  if (token == null || token.isEmpty) {
    _bail('GITHUB_TOKEN not set in environment. '
          'Either `export GITHUB_TOKEN=...` or pass --no-upload.');
  }

  final tag = flags.tag ?? await _autoBumpTag(token!);
  _step('Creating release $tag on $_repo');
  final releaseId = await _ensureRelease(token, tag, flags.notes);

  for (final f in artifacts) {
    _step('Uploading ${_basename(f.path)}');
    await _uploadAsset(token, releaseId, f);
  }

  _ok('Release $tag published with ${artifacts.length} artifact(s).');
  print('   https://github.com/$_repo/releases/tag/$tag');
}

// ─── Flags ──────────────────────────────────────────────────────────────────
class _Flags {
  final String? tag;
  final bool    androidOnly;
  final bool    noUpload;
  final String  notes;
  _Flags({this.tag, required this.androidOnly, required this.noUpload, required this.notes});
}

_Flags _parseFlags(List<String> args) {
  String?  tag;
  bool     androidOnly = false;
  bool     noUpload    = false;
  String   notes = 'Automated release built by tool/deploy.dart.';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--tag':           tag = args[++i]; break;
      case '--android-only':  androidOnly = true; break;
      case '--no-upload':     noUpload    = true; break;
      case '--notes':         notes       = args[++i]; break;
    }
  }
  return _Flags(tag: tag, androidOnly: androidOnly, noUpload: noUpload, notes: notes);
}

// ─── Process helpers ────────────────────────────────────────────────────────
Future<void> _run(String exe, List<String> args) async {
  final p = await Process.start(exe, args, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (code != 0) _bail('$exe ${args.join(' ')} exited $code');
}

void _step(String msg) => print('\n\x1B[36m▶ $msg\x1B[0m');
void _ok(String msg)   => print('\n\x1B[32m✓ $msg\x1B[0m');
void _note(String msg) => print('  \x1B[90m· $msg\x1B[0m');
Never _bail(String msg) {
  stderr.writeln('\x1B[31m✗ $msg\x1B[0m');
  exit(1);
}

// ─── Archive helpers ────────────────────────────────────────────────────────
String _basename(String p) => p.split(RegExp(r'[\\/]')).last;

Future<File> _zipDir(Directory dir, String name) async {
  await Directory('build/dist').create(recursive: true);
  final out = File('build/dist/$name');
  if (Platform.isWindows) {
    await _run('powershell', ['-Command',
      'Compress-Archive -Path "${dir.path}\\*" -DestinationPath "${out.path}" -Force']);
  } else {
    await _run('zip', ['-r', '-q', out.absolute.path, '.'], );
  }
  return out;
}

Future<File> _tarDir(Directory dir, String name) async {
  await Directory('build/dist').create(recursive: true);
  final out = File('build/dist/$name');
  await _run('tar', ['-C', dir.path, '-czf', out.absolute.path, '.']);
  return out;
}

// ─── GitHub API ─────────────────────────────────────────────────────────────
Future<String> _autoBumpTag(String token) async {
  final res = await HttpClient()
      .getUrl(Uri.parse('https://api.github.com/repos/$_repo/releases/latest'))
      .then((r) {
        r.headers.set('Authorization', 'Bearer $token');
        r.headers.set('Accept', 'application/vnd.github+json');
        return r.close();
      });
  if (res.statusCode == 404) return 'v1.0.0';
  final body = await res.transform(utf8.decoder).join();
  final latest = (jsonDecode(body) as Map)['tag_name'] as String? ?? 'v1.0.0';
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(latest);
  if (m == null) return 'v1.0.0';
  return 'v${m.group(1)}.${m.group(2)}.${int.parse(m.group(3)!) + 1}';
}

Future<int> _ensureRelease(String token, String tag, String notes) async {
  final client = HttpClient();
  // Look up the existing release by tag first.
  var req = await client.getUrl(
      Uri.parse('https://api.github.com/repos/$_repo/releases/tags/$tag'));
  req.headers.set('Authorization', 'Bearer $token');
  req.headers.set('Accept', 'application/vnd.github+json');
  var res = await req.close();
  if (res.statusCode == 200) {
    final body = await res.transform(utf8.decoder).join();
    return (jsonDecode(body) as Map)['id'] as int;
  }
  // Create it.
  req = await client.postUrl(
      Uri.parse('https://api.github.com/repos/$_repo/releases'));
  req.headers.set('Authorization', 'Bearer $token');
  req.headers.set('Accept', 'application/vnd.github+json');
  req.headers.set('Content-Type', 'application/json');
  req.add(utf8.encode(jsonEncode({
    'tag_name':   tag,
    'name':       'Portfolio Admin $tag',
    'body':       notes,
    'draft':      false,
    'prerelease': false,
  })));
  res = await req.close();
  if (res.statusCode >= 400) {
    final body = await res.transform(utf8.decoder).join();
    _bail('Create release failed (${res.statusCode}): $body');
  }
  final body = await res.transform(utf8.decoder).join();
  return (jsonDecode(body) as Map)['id'] as int;
}

Future<void> _uploadAsset(String token, int releaseId, File asset) async {
  // Delete any pre-existing asset with the same name (release upload API
  // rejects collisions with 422 "already_exists").
  final list = await _http('GET', Uri.parse(
      'https://api.github.com/repos/$_repo/releases/$releaseId/assets'), token);
  for (final a in (jsonDecode(list) as List).cast<Map>()) {
    if (a['name'] == _basename(asset.path)) {
      await _http('DELETE',
          Uri.parse('https://api.github.com/repos/$_repo/releases/assets/${a['id']}'),
          token);
    }
  }

  final upload = await HttpClient().postUrl(Uri.parse(
      'https://uploads.github.com/repos/$_repo/releases/$releaseId/assets'
      '?name=${_basename(asset.path)}'));
  upload.headers.set('Authorization', 'Bearer $token');
  upload.headers.set('Content-Type', _contentTypeFor(asset.path));
  upload.headers.set('Accept', 'application/vnd.github+json');
  await asset.openRead().pipe(upload);
  final res = await upload.done;
  if (res.statusCode >= 400) {
    _bail('Upload of ${asset.path} failed (${res.statusCode})');
  }
}

String _contentTypeFor(String path) {
  if (path.endsWith('.apk')) return 'application/vnd.android.package-archive';
  if (path.endsWith('.zip')) return 'application/zip';
  if (path.endsWith('.tar.gz')) return 'application/gzip';
  return 'application/octet-stream';
}

Future<String> _http(String method, Uri uri, String token) async {
  final c = HttpClient();
  final req = await c.openUrl(method, uri);
  req.headers.set('Authorization', 'Bearer $token');
  req.headers.set('Accept', 'application/vnd.github+json');
  final res = await req.close();
  return res.transform(utf8.decoder).join();
}
