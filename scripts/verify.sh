#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/.build/verification"
OUTPUT_PATH="$OUTPUT_DIR/TwigDockVerification"
INTEGRATION_PATH="$OUTPUT_DIR/TwigDockGitIntegration"

/bin/mkdir -p "$OUTPUT_DIR"
/usr/bin/swiftc \
    -warnings-as-errors \
    -parse-as-library \
    "$PROJECT_ROOT/Sources/TwigDock/Models.swift" \
    "$PROJECT_ROOT/Sources/TwigDock/CommandRunner.swift" \
    "$PROJECT_ROOT/Sources/TwigDock/PortService.swift" \
    "$PROJECT_ROOT/Sources/TwigDock/GitWorktreeService.swift" \
    "$SCRIPT_DIR/verify-parsers.swift" \
    -o "$OUTPUT_PATH"

"$OUTPUT_PATH"

/usr/bin/swiftc \
    -warnings-as-errors \
    -parse-as-library \
    "$PROJECT_ROOT/Sources/TwigDock/Models.swift" \
    "$PROJECT_ROOT/Sources/TwigDock/CommandRunner.swift" \
    "$PROJECT_ROOT/Sources/TwigDock/PortService.swift" \
    "$PROJECT_ROOT/Sources/TwigDock/GitWorktreeService.swift" \
    "$SCRIPT_DIR/verify-git-integration.swift" \
    -o "$INTEGRATION_PATH"

"$INTEGRATION_PATH"
