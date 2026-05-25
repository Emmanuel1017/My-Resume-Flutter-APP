# Upload js-dos Files to GitHub - Quick Guide

## Files Ready to Upload ✅

I've downloaded the correct js-dos v8 files and placed them in your Flutter project:

**Location**: `C:\Users\user\portfolio-admin\assets\doom\`

**Files**:
- ✅ `js-dos.js` (302KB) - Main library
- ✅ `wdosbox.js` (101KB) - DOSBox emulator wrapper  
- ✅ `wdosbox.wasm` (1.4MB) - WebAssembly binary

## Upload to Angular-Resume Repo

You need to copy these 3 files to your **Angular-Resume** repository:

### Step 1: Copy Files

```bash
# Navigate to your Angular-Resume repo
cd /path/to/Angular-Resume

# Copy the files from Flutter project
cp "C:/Users/user/portfolio-admin/assets/doom/js-dos.js" src/assets/doom/
cp "C:/Users/user/portfolio-admin/assets/doom/wdosbox.js" src/assets/doom/
cp "C:/Users/user/portfolio-admin/assets/doom/wdosbox.wasm" src/assets/doom/
```

### Step 2: Commit and Push

```bash
cd /path/to/Angular-Resume

# Add files to git
git add src/assets/doom/js-dos.js
git add src/assets/doom/wdosbox.js
git add src/assets/doom/wdosbox.wasm

# Commit
git commit -m "feat: add js-dos v8 library files for offline DOOM emulation

- js-dos.js (302KB) - main emulator library
- wdosbox.js (101KB) - DOSBox wrapper
- wdosbox.wasm (1.4MB) - WebAssembly binary

These files allow the Flutter portfolio app to run DOOM completely
offline after first download. Files are cached locally in the app."

# Push to GitHub
git push origin master
```

### Step 3: Verify Upload

Check that the files are accessible:

```bash
curl -I https://raw.githubusercontent.com/Emmanuel1017/Angular-Resume/master/src/assets/doom/js-dos.js
curl -I https://raw.githubusercontent.com/Emmanuel1017/Angular-Resume/master/src/assets/doom/wdosbox.js
curl -I https://raw.githubusercontent.com/Emmanuel1017/Angular-Resume/master/src/assets/doom/wdosbox.wasm
```

All should return `HTTP/1.1 200 OK`

## Then Test Flutter App

Once uploaded to GitHub, run your Flutter app:

```bash
cd /path/to/portfolio-admin
flutter run -d android
```

### Expected Logs:

```
[DOOM] Loading game: DOOM
[DOOM] js-dos library cached: false
[DOOM] Downloading js-dos library from GitHub...
[DoomCache] Downloading js-dos.js from GitHub...
[DoomCache] Cached js-dos.js (302584 bytes)
[DoomCache] Downloading wdosbox.js from GitHub...
[DoomCache] Cached wdosbox.js (101123 bytes)  
[DoomCache] Downloading wdosbox.wasm from GitHub...
[DoomCache] Cached wdosbox.wasm (1436859 bytes)
[DOOM] js-dos library cached successfully
[DOOM] WAD cached: true
[DOOM] js-dos.js loaded: 302584 characters
[DOOM] wdosbox.js loaded: 101123 characters
[DOOM] wdosbox.wasm loaded: 1436859 bytes
[DOOM] js-dos.js injected
[DOOM] wdosbox.wasm data injected
[DOOM] wdosbox.js injected
[DOOM HTML] Dos instance created
[DOOM HTML] Bundle extracted, starting game...
```

## Alternative: Use Git Directly

If you're on Windows and have Git Bash:

```bash
#!/bin/bash
# Quick upload script

ANGULAR_REPO="/c/path/to/Angular-Resume"
FLUTTER_DOOM="C:/Users/user/portfolio-admin/assets/doom"

# Copy files
cp "$FLUTTER_DOOM/js-dos.js" "$ANGULAR_REPO/src/assets/doom/"
cp "$FLUTTER_DOOM/wdosbox.js" "$ANGULAR_REPO/src/assets/doom/"
cp "$FLUTTER_DOOM/wdosbox.wasm" "$ANGULAR_REPO/src/assets/doom/"

# Commit and push
cd "$ANGULAR_REPO"
git add src/assets/doom/*.js src/assets/doom/*.wasm
git commit -m "feat: add js-dos v8 library for offline DOOM"
git push origin master

echo "✅ Uploaded to GitHub!"
```

## File Sizes

| File | Size | Purpose |
|------|------|---------|
| js-dos.js | 302 KB | Main emulator library |
| wdosbox.js | 101 KB | DOSBox JavaScript wrapper |
| wdosbox.wasm | 1.4 MB | WebAssembly DOSBox binary |
| **Total** | **~1.8 MB** | One-time download |

Combined with WAD files (~5-7MB), total first download is ~7-9MB.

---

**⚠️ ACTION REQUIRED**: Upload these 3 files to GitHub, then test the Flutter app!
