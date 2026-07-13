#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# CocoaPods crashes without a UTF-8 locale.
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Install the same Flutter version the project is pinned to via fvm (.fvmrc).
FLUTTER_VERSION=$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' .fvmrc)
if [ -z "$FLUTTER_VERSION" ]; then
  echo "error: could not read Flutter version from .fvmrc" >&2
  exit 1
fi
git clone https://github.com/flutter/flutter.git --depth 1 -b $FLUTTER_VERSION $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

# Install Flutter dependencies.
flutter pub get

# Install CocoaPods using Homebrew.
export HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install # run `pod install` in the `ios` directory.

exit 0
