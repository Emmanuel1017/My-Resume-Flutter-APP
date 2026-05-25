# DOOM Assets Directory

## Contents

### Game Bundles (.jsdos files)
- `doom.jsdos` (5.5 MB) - DOOM Episode 1: Knee-Deep in the Dead (shareware)
- `doom2.jsdos` (7.0 MB) - DOOM II: Hell on Earth

These are pre-packaged js-dos bundles containing:
- The DOS game executable
- Game data files (WAD files)
- DOSBox configuration
- Autostart scripts

### Cover Images
- `doom1-cover.jpg` - DOOM cover art
- `doom2-cover.jpg` - DOOM II cover art  
- `doomguy-face.jpg` - Doomguy status bar face (used during loading)

### HTML Player
- `doom_player.html` - The WebView HTML file that:
  - Loads js-dos emulator from CDN (requires internet)
  - Receives WAD data from Flutter via JavaScript bridge
  - Initializes DOSBox and runs the game
  - Handles loading states and errors

### Documentation
- `download_jsdos.md` - Instructions for bundling js-dos locally
- `README.md` - This file

## How It Works

1. User selects a game from the Flutter UI
2. `DoomCacheService` checks if the `.jsdos` file is cached locally
3. If not cached, downloads from GitHub and caches in app directory
4. Flutter loads `doom_player.html` in a WebView
5. HTML loads js-dos emulator from CDN (requires internet connection)
6. Flutter injects the `.jsdos` file as base64 data into JavaScript
7. js-dos extracts the bundle and starts DOSBox
8. Game runs in the WebView

## Internet Requirements

**Required on first launch per session:**
- js-dos library (~500KB)
- wdosbox WASM (~5MB)

**Cached locally forever:**
- Game `.jsdos` bundles (5-7MB each)
- Cover images
- Doomguy face

## Offline Alternative

To make DOOM work completely offline, you would need to:

1. Download js-dos v7 files locally:
   ```bash
   # These URLs are examples - actual CDN URLs may vary
   curl -o vendor/js-dos.js https://js-dos.com/v7/build/js-dos.js
   curl -o vendor/wdosbox.wasm.js https://js-dos.com/v7/build/wdosbox.wasm.js
   curl -o vendor/wdosbox.wasm https://js-dos.com/v7/build/wdosbox.wasm
   ```

2. Update `doom_player.html` to load from local files instead of CDN

3. Add vendor files to `pubspec.yaml` assets

However, this adds ~6MB to the app bundle and requires manual js-dos updates.

## License & Attribution

- **DOOM** - id Software (shareware episode is freely distributable)
- **js-dos** - https://js-dos.com - DOS emulator in browser
- **Implementation** - Emmanuel1017

## Controls

- **Arrow Keys** - Move
- **CTRL** - Fire weapon
- **SPACE** - Use/Open doors
- **ALT** - Strafe
- **1-7** - Select weapon
- **ESC** - Menu
