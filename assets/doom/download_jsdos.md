# How to Bundle js-dos Locally for Offline DOOM

The issue you're experiencing is that the app tries to load js-dos from the internet (`https://js-dos.com`), which fails without connectivity.

## Solution: Use DOSBox-WASM Instead

js-dos v7 is complex to bundle. A better approach is to use **em-dosbox** or create a simpler solution.

## Option 1: Load from CDN (Requires Internet)

Update `doom_player.html` to load from CDN - this is what you currently have, but it needs internet.

## Option 2: Use a Native DOSBox Plugin (Recommended)

Instead of WebView + js-dos, use a native Flutter DOSBox implementation:

### For Flutter:
There isn't a well-maintained DOSBox plugin for Flutter yet. The best options are:

1. **Use WebView with online js-dos** (current approach - requires internet)
2. **Build a native DOSBox integration** using platform channels (complex)
3. **Use a simpler game format** (like DOOM in WebAssembly without DOSBox)

## Option 3: Bundle js-dos v7 Files Locally

To make js-dos work offline, you need these files in `assets/doom/`:

```
js-dos.js          (the main library)
wdosbox.wasm.js    (the WebAssembly DOSBox emulator)
wdosbox.wasm       (WASM binary)
```

### Steps:

1. Download js-dos v7 files:
   ```bash
   curl -o assets/doom/js-dos.js https://js-dos.com/v7/build/js-dos.js
   curl -o assets/doom/wdosbox.wasm.js https://js-dos.com/v7/build/wdosbox.wasm.js
   curl -o assets/doom/wdosbox.wasm https://js-dos.com/v7/build/wdosbox.wasm
   ```

2. Update `pubspec.yaml` to include these files (already done)

3. Update `doom_player.html` to load from local assets instead of CDN

## Option 4: Alternative - DOOM in Pure WASM (Best for Offline)

Use a WASM build of DOOM that doesn't need DOSBox:

- **doom-wasm**: A direct WebAssembly port of DOOM
- Smaller, faster, no emulator needed
- Works completely offline

Would you like me to implement Option 3 (download js-dos files) or Option 4 (use WASM DOOM)?

## Quick Fix: Download js-dos Now

Run these commands:
