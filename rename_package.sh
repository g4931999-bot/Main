#!/bin/bash
# ==============================================================================
# Renames the Android package name everywhere it appears:
#   FROM: com.tubepilot.tubepilot_flutter
#   TO:   com.example.tubepilot_flutter
# Run this from inside the tubepilot_flutter/ folder.
# ==============================================================================
set -e

OLD_PACKAGE="com.tubepilot.tubepilot_flutter"
NEW_PACKAGE="com.example.tubepilot_flutter"
OLD_PATH=$(echo "$OLD_PACKAGE" | tr '.' '/')
NEW_PATH=$(echo "$NEW_PACKAGE" | tr '.' '/')

echo "=================================================="
echo "STEP 1: Updating android/app/build.gradle.kts"
echo "=================================================="
GRADLE_FILE="android/app/build.gradle.kts"
if [ -f "$GRADLE_FILE" ]; then
  sed -i "s/$OLD_PACKAGE/$NEW_PACKAGE/g" "$GRADLE_FILE"
  echo "Updated applicationId/namespace in $GRADLE_FILE"
  grep -n "applicationId\|namespace" "$GRADLE_FILE"
else
  echo "⚠️  $GRADLE_FILE not found — check the path manually"
fi

echo ""
echo "=================================================="
echo "STEP 2: Moving Kotlin MainActivity.kt to new package folder"
echo "=================================================="
OLD_KOTLIN_DIR="android/app/src/main/kotlin/$OLD_PATH"
NEW_KOTLIN_DIR="android/app/src/main/kotlin/$NEW_PATH"

if [ -f "$OLD_KOTLIN_DIR/MainActivity.kt" ]; then
  mkdir -p "$NEW_KOTLIN_DIR"
  git mv "$OLD_KOTLIN_DIR/MainActivity.kt" "$NEW_KOTLIN_DIR/MainActivity.kt" 2>/dev/null || \
    mv "$OLD_KOTLIN_DIR/MainActivity.kt" "$NEW_KOTLIN_DIR/MainActivity.kt"

  # Update the "package ..." declaration inside the file itself
  sed -i "s/package $OLD_PACKAGE/package $NEW_PACKAGE/" "$NEW_KOTLIN_DIR/MainActivity.kt"
  echo "Moved MainActivity.kt to $NEW_KOTLIN_DIR and updated its package declaration"

  # Clean up now-empty old folders
  find "android/app/src/main/kotlin/$(echo $OLD_PACKAGE | cut -d'.' -f1)" -type d -empty -delete 2>/dev/null || true
else
  echo "⚠️  Could not find MainActivity.kt at $OLD_KOTLIN_DIR — check manually with:"
  echo "    find android/app/src/main -name MainActivity.kt"
fi

echo ""
echo "=================================================="
echo "STEP 3: Checking AndroidManifest.xml files for the old package"
echo "=================================================="
grep -rl "$OLD_PACKAGE" android/app/src/*/AndroidManifest.xml 2>/dev/null && {
  sed -i "s/$OLD_PACKAGE/$NEW_PACKAGE/g" android/app/src/*/AndroidManifest.xml
  echo "Updated AndroidManifest.xml file(s)"
} || echo "No AndroidManifest.xml files reference the package directly (normal for newer Flutter templates)"

echo ""
echo "=================================================="
echo "STEP 4: Verifying no old package references remain"
echo "=================================================="
echo "Searching for any leftover '$OLD_PACKAGE'..."
grep -rn "$OLD_PACKAGE" android/ 2>/dev/null | grep -v "/build/" || echo "✅ None found — fully renamed"

echo ""
echo "=================================================="
echo "STEP 5: IMPORTANT - manual steps still needed"
echo "=================================================="
echo "1. Download the google-services.json for package '$NEW_PACKAGE' from Firebase"
echo "   (Firebase Console -> Project Settings -> your Android app -> google-services.json)"
echo "   and REPLACE android/app/google-services.json with it."
echo ""
echo "2. In lib/config.dart, double check googleServerClientId still matches"
echo "   the Web Client ID (package name change does not affect this value)."
echo ""
echo "3. Then run:"
echo "   flutter clean && flutter pub get && flutter build apk --debug"
