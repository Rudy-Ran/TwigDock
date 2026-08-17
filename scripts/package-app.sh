#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/TwigDock.app"
CONTENTS_PATH="$APP_PATH/Contents"

if [[ "$APP_PATH" != "$PROJECT_ROOT/dist/TwigDock.app" ]]; then
    print -u2 "拒绝清理无法确认的应用路径：$APP_PATH"
    exit 2
fi

/usr/bin/swift build -c release --package-path "$PROJECT_ROOT"
BIN_PATH="$(/usr/bin/swift build -c release --package-path "$PROJECT_ROOT" --show-bin-path)"

if [[ -e "$APP_PATH" ]]; then
    /bin/rm -rf "$APP_PATH"
fi

/bin/mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
/bin/cp "$BIN_PATH/TwigDock" "$CONTENTS_PATH/MacOS/TwigDock"
/bin/cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_PATH/Info.plist"
"$SCRIPT_DIR/generate-icon.sh" "$CONTENTS_PATH/Resources/TwigDock.icns"
/bin/chmod 755 "$CONTENTS_PATH/MacOS/TwigDock"

/usr/bin/codesign --force --deep --sign - "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"

print "$APP_PATH"
