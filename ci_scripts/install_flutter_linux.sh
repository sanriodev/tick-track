#!/usr/bin/env bash

# Installs the Flutter version this project is pinned to via fvm (.fvmrc).
# Linux/CI counterpart to ios/ci_scripts/ci_post_clone.sh — .fvmrc stays the
# single source of truth for the Flutter version on every platform.
#
# Usage:
#   ./ci_scripts/install_flutter_linux.sh
#   export PATH="$FLUTTER_HOME/bin:$PATH"

set -e

cd "$(dirname "$0")/.."

FLUTTER_VERSION=$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' .fvmrc)
if [ -z "$FLUTTER_VERSION" ]; then
  echo "error: could not read Flutter version from .fvmrc" >&2
  exit 1
fi

# Defaults to the location baked into the CI image; falls back to a cacheable
# path inside the project when running somewhere without a preinstalled SDK.
FLUTTER_HOME="${FLUTTER_HOME:-$PWD/.flutter}"

# The SDK may be owned by a different uid than the job user.
git config --global --add safe.directory "$FLUTTER_HOME" 2>/dev/null || true

# Reuse an existing SDK only if it is exactly the pinned version.
if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
  INSTALLED=$(git -C "$FLUTTER_HOME" describe --tags --exact-match 2>/dev/null || true)
  if [ -z "$INSTALLED" ]; then
    # Shallow clones can lack the tag — fall back to what the SDK reports.
    INSTALLED=$("$FLUTTER_HOME/bin/flutter" --version 2>/dev/null \
      | sed -n 's/^Flutter \([0-9][^ ]*\).*/\1/p' | head -1)
  fi
  if [ "$INSTALLED" = "$FLUTTER_VERSION" ]; then
    echo "Flutter $FLUTTER_VERSION already present at $FLUTTER_HOME — skipping install"
    export PATH="$FLUTTER_HOME/bin:$PATH"
    flutter --version
    exit 0
  fi
  echo "Found Flutter ${INSTALLED:-unknown}, need $FLUTTER_VERSION — reinstalling"
  rm -rf "$FLUTTER_HOME"
fi

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION"
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

# The SDK is cached across jobs and may be owned by a different uid.
git config --global --add safe.directory "$FLUTTER_HOME"

flutter precache --android --no-ios --no-macos --no-linux --no-windows --no-web
flutter --version
