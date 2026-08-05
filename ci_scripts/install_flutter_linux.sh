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

# Keep the SDK inside the project dir so GitLab CI can cache it.
FLUTTER_HOME="${FLUTTER_HOME:-$PWD/.flutter}"

# Reuse a cached SDK only if it is exactly the pinned version.
if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
  INSTALLED=$(git -C "$FLUTTER_HOME" describe --tags --exact-match 2>/dev/null || echo "unknown")
  if [ "$INSTALLED" = "$FLUTTER_VERSION" ]; then
    echo "Flutter $FLUTTER_VERSION already present at $FLUTTER_HOME"
  else
    echo "Cached Flutter is $INSTALLED, need $FLUTTER_VERSION — reinstalling"
    rm -rf "$FLUTTER_HOME"
  fi
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
