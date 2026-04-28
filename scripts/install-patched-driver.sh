#!/usr/bin/env bash
# install-patched-driver.sh
# 1. Installs appium-tizen-tv-driver globally via npm
# 2. Applies the improvements patch
# 3. Registers the patched driver with Appium
#
# Usage: bash scripts/install-patched-driver.sh
# Requires: patch, npm, appium

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/tizen-tv-driver-improvements.patch"

# ── 1. Locate npm global prefix ──────────────────────────────────────────────
NPM_PREFIX="$(npm config get prefix)"
DRIVER_DIR="$NPM_PREFIX/lib/node_modules/appium-tizen-tv-driver"

echo "══════════════════════════════════════════════════"
echo " Tizen TV Driver – patched install"
echo "══════════════════════════════════════════════════"

# ── 2. Check patch file exists ────────────────────────────────────────────────
if [ ! -f "$PATCH_FILE" ]; then
  echo "✖ Patch file not found: $PATCH_FILE"
  echo "  Run  bash scripts/generate-patch.sh  first."
  exit 1
fi

# ── 3. Remove existing driver if present ─────────────────────────────────────
if [ -d "$DRIVER_DIR" ]; then
  echo ""
  echo "→ Removing existing driver at $DRIVER_DIR..."
  rm -rf "$DRIVER_DIR"
  echo "✔ Removed"
fi

# ── 4. Install the published driver globally ──────────────────────────────────
echo ""
echo "→ Step 1/3 – Installing appium-tizen-tv-driver from npm..."
npm install -g appium-tizen-tv-driver
echo "✔ Installed to: $DRIVER_DIR"

# ── 4. Apply patch ───────────────────────────────────────────────────────────
echo ""
echo "→ Step 2/3 – Applying patch..."
pushd "$DRIVER_DIR" > /dev/null

# Dry-run first to detect any issues
if ! patch --dry-run -p1 --forward < "$PATCH_FILE" > /dev/null 2>&1; then
  echo "  ⚠ Dry-run check failed – attempting to apply anyway (patch may be partially applied)..."
fi

patch -p1 --forward --reject-file=/tmp/tizen-tv-driver.rej < "$PATCH_FILE" && {
  echo "✔ Patch applied successfully"
} || {
  EXIT=$?
  if [ $EXIT -eq 1 ] && [ -f /tmp/tizen-tv-driver.rej ]; then
    echo "✖ Some hunks failed to apply. Rejected hunks saved to /tmp/tizen-tv-driver.rej"
    cat /tmp/tizen-tv-driver.rej
    popd > /dev/null
    exit 1
  fi
}

# Fix version in package.json to 1.0.6
sed -i '' 's/"version": "1.0.5"/"version": "1.0.6"/' "$DRIVER_DIR/package.json" 2>/dev/null || \
  sed -i 's/"version": "1.0.5"/"version": "1.0.6"/' "$DRIVER_DIR/package.json"

echo "✔ Version bumped to 1.0.6 in $DRIVER_DIR/package.json"

popd > /dev/null

# ── 5. Register with Appium ──────────────────────────────────────────────────
echo ""
echo "→ Step 3/3 – Registering driver with Appium..."
appium driver install appium-tizen-tv-driver --source=local
echo ""
echo "══════════════════════════════════════════════════"
echo "✔ Done! appium-tizen-tv-driver (patched) is ready."
echo "══════════════════════════════════════════════════"
appium driver list --installed 2>/dev/null | grep -i tizen || true

