#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

echo "🔨 Building CustomVolumeHUD in Release mode..."
./scripts/build_app.sh

echo "📦 Installing to /Applications/CustomVolumeHUD.app..."
pkill -x CustomVolumeHUD 2>/dev/null || true
rm -rf /Applications/CustomVolumeHUD.app
cp -R CustomVolumeHUD.app /Applications/

echo "🚀 Registering CustomVolumeHUD to start on login..."
/Applications/CustomVolumeHUD.app/Contents/MacOS/CustomVolumeHUD --enable-login

echo "✨ Launching CustomVolumeHUD from /Applications..."
open /Applications/CustomVolumeHUD.app

echo "✅ CustomVolumeHUD installed successfully and configured to start on login!"
