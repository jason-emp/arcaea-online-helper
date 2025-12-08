#!/bin/bash
set -e


echo "=== Build Android universal APK ==="
flutter build apk --release \
  --target-platform android-arm,android-arm64,android-x64

echo "=== Build Android split-per-abi APKs ==="
flutter build apk --release --split-per-abi

echo "=== Build iOS IPA (no-codesign) ==="
flutter build ipa --release --export-method development

echo "=== ALL BUILD DONE ==="