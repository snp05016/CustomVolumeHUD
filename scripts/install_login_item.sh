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

echo "🚀 Registering ${APP_PATH} as a login item..."
if [ -f "${APP_PATH}/Contents/MacOS/CustomVolumeHUD" ]; then
    "${APP_PATH}/Contents/MacOS/CustomVolumeHUD" --enable-login
else
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"${APP_PATH}\", hidden:false, name:\"CustomVolumeHUD\"}"
fi

echo "✅ CustomVolumeHUD registered to start on login."
