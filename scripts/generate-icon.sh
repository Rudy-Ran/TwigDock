#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_PATH="${1:-}"

if [[ -z "$OUTPUT_PATH" || "${OUTPUT_PATH##*.}" != "icns" ]]; then
    print -u2 "用法：$0 /absolute/path/TwigDock.icns"
    exit 2
fi

ICON_WORK="$(mktemp -d -t TwigDockIcon)"
ICONSET_PATH="$ICON_WORK/TwigDock.iconset"

cleanup() {
    case "$ICON_WORK" in
        /private/var/folders/*|/tmp/*) /bin/rm -rf "$ICON_WORK" ;;
    esac
}
trap cleanup EXIT

/bin/mkdir -p "$ICONSET_PATH" "$(dirname "$OUTPUT_PATH")"
/usr/bin/swift "$SCRIPT_DIR/generate-icon.swift" "$ICONSET_PATH"
/usr/bin/iconutil -c icns "$ICONSET_PATH" -o "$OUTPUT_PATH"
