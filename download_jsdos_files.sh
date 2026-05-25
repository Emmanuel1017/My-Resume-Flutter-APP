#!/bin/bash

# Script to download js-dos library files for DOOM emulation
# Run this in your Angular-Resume/src/assets/doom directory

echo "================================================"
echo "  DOOM js-dos Library Downloader"
echo "================================================"
echo ""

# Check if we're in the right directory
if [ ! -f "doom.jsdos" ]; then
    echo "⚠️  Warning: doom.jsdos not found in current directory"
    echo "   Make sure you're in: Angular-Resume/src/assets/doom/"
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📥 Downloading js-dos v7 library files from CDN..."
echo ""

# Try multiple CDN sources

# Method 1: dos.zone CDN (most reliable)
echo "Trying dos.zone CDN..."
curl -L -o js-dos.js "https://cdn.dos.zone/v7/js-dos/js-dos.js" 2>/dev/null
curl -L -o wdosbox.wasm.js "https://cdn.dos.zone/v7/js-dos/wdosbox.wasm.js" 2>/dev/null
curl -L -o wdosbox.wasm "https://cdn.dos.zone/v7/js-dos/wdosbox.wasm" 2>/dev/null

# Check if files were downloaded
if [ -f "js-dos.js" ] && [ $(stat -f%z "js-dos.js" 2>/dev/null || stat -c%s "js-dos.js" 2>/dev/null) -gt 100000 ]; then
    echo "✅ js-dos.js downloaded successfully"
else
    echo "❌ js-dos.js download failed or file too small"
    echo "Trying jsdelivr CDN..."
    curl -L -o js-dos.js "https://cdn.jsdelivr.net/npm/js-dos@7.22.0/dist/js-dos.js"
fi

if [ -f "wdosbox.wasm.js" ] && [ $(stat -f%z "wdosbox.wasm.js" 2>/dev/null || stat -c%s "wdosbox.wasm.js" 2>/dev/null) -gt 1000000 ]; then
    echo "✅ wdosbox.wasm.js downloaded successfully"
else
    echo "❌ wdosbox.wasm.js download failed or file too small"
    echo "Trying jsdelivr CDN..."
    curl -L -o wdosbox.wasm.js "https://cdn.jsdelivr.net/npm/js-dos@7.22.0/dist/wdosbox.wasm.js"
fi

if [ -f "wdosbox.wasm" ] && [ $(stat -f%z "wdosbox.wasm" 2>/dev/null || stat -c%s "wdosbox.wasm" 2>/dev/null) -gt 1000000 ]; then
    echo "✅ wdosbox.wasm downloaded successfully"
else
    echo "❌ wdosbox.wasm download failed or file too small"
    echo "Trying jsdelivr CDN..."
    curl -L -o wdosbox.wasm "https://cdn.jsdelivr.net/npm/js-dos@7.22.0/dist/wdosbox.wasm"
fi

echo ""
echo "📊 Download Summary:"
echo "==================="
ls -lh js-dos.js wdosbox.wasm.js wdosbox.wasm 2>/dev/null || echo "Some files failed to download"

echo ""
echo "✅ Done! Now commit and push to GitHub:"
echo ""
echo "   git add js-dos.js wdosbox.wasm.js wdosbox.wasm"
echo "   git commit -m 'feat: add js-dos library files for offline DOOM'"
echo "   git push"
echo ""
echo "Then run your Flutter app and DOOM should work offline! 🎮"
