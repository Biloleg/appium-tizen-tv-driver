#!/usr/bin/env bash
# generate-patch.sh
# Creates tizen-tv-driver-improvements.patch from the diff between the published
# npm package (appium-tizen-tv-driver@1.0.5) and the current project.
#
# Usage: bash scripts/generate-patch.sh
# Output: scripts/tizen-tv-driver-improvements.patch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# Point to the monorepo package instead of root
PACKAGE_DIR="$PROJECT_DIR/packages/appium-tizen-tv-driver"
PATCH_FILE="$SCRIPT_DIR/tizen-tv-driver-improvements.patch"
TMP_DIR="$(mktemp -d)"
NPM_PKG_VERSION="0.18.1"

echo "→ Downloading appium-tizen-tv-driver@${NPM_PKG_VERSION} from npm..."
if ! npm pack "appium-tizen-tv-driver@${NPM_PKG_VERSION}" --pack-destination "$TMP_DIR" 2>&1; then
  echo "✖ Failed to download package. Check npm registry and version availability."
  rm -rf "$TMP_DIR"
  exit 1
fi

PACKED_FILE="$TMP_DIR/appium-tizen-tv-driver-${NPM_PKG_VERSION}.tgz"
if [ ! -f "$PACKED_FILE" ]; then
  echo "✖ Package file not found at $PACKED_FILE"
  rm -rf "$TMP_DIR"
  exit 1
fi

if ! tar -xzf "$PACKED_FILE" -C "$TMP_DIR" --strip-components=1; then
  echo "✖ Failed to extract package"
  rm -rf "$TMP_DIR"
  exit 1
fi
echo "✔ Downloaded and extracted successfully"

echo "→ Generating patch..."

# Files to patch (lib/ JS sources + package.json)
PATCH_FILES=(
  "lib/cli/helpers.js"
  "lib/cli/sdb.js"
  "lib/cli/tizen.js"
  "lib/desired-caps.js"
  "lib/driver.js"
  "lib/logger.js"
  "lib/scripts.js"
  "lib/keymap.js"
  "lib/rc-pair.js"
  "lib/server.js"
  "package.json"
)

# Write unified diff for each changed file
{
  for f in "${PATCH_FILES[@]}"; do
    orig="$TMP_DIR/$f"
    curr="$PACKAGE_DIR/$f"
    if [ ! -f "$orig" ]; then
      echo "  ! Skipping $f (not in npm package)"
      continue
    fi
    if ! diff -q "$orig" "$curr" >/dev/null 2>&1; then
      diff -u \
        --label "a/$f" \
        --label "b/$f" \
        "$orig" "$curr" || true   # diff exits 1 when files differ; "|| true" prevents set -e abort
    fi
  done
} > "$PATCH_FILE"

echo "→ Cleaning up..."
rm -rf "$TMP_DIR"

LINES=$(wc -l < "$PATCH_FILE" | tr -d ' ')
echo "✔ Patch written to: $PATCH_FILE  (${LINES} lines)"

