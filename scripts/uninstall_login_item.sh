#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

APP_PATH="/Applications/CustomVolumeHUD.app"
if [ ! -d "$APP_PATH" ]; then
    if [ -d "$ROOT_DIR/CustomVolumeHUD.app" ]; then
        APP_PATH="$ROOT_DIR/CustomVolumeHUD.app"
    fi
fi

echo "🛑 Removing CustomVolumeHUD from login items..."
if [ -f "${APP_PATH}/Contents/MacOS/CustomVolumeHUD" ]; then
    "${APP_PATH}/Contents/MacOS/CustomVolumeHUD" --disable-login || true
else
    osascript -e 'tell application "System Events" to if exists (login item "CustomVolumeHUD") then delete (login item "CustomVolumeHUD")'
fi

echo "✅ CustomVolumeHUD removed from login items."
