#!/bin/bash
# ==============================================================================
# Tube Pilot - GitHub Codespaces Setup Script
# Installs Flutter + Android SDK, sets PATH, accepts licenses, checks Java,
# and builds the debug APK. Safe to re-run if something fails partway.
# ==============================================================================
set -e  # stop immediately if any command fails

echo "=================================================="
echo "STEP 1: Checking Java"
echo "=================================================="
if ! command -v java &> /dev/null; then
  echo "Java not found — installing OpenJDK 17..."
  sudo apt-get update -y
  sudo apt-get install -y openjdk-17-jdk
else
  echo "Java already installed:"
  java -version
fi

# Make sure JAVA_HOME is set correctly (Android tooling needs this)
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "JAVA_HOME=$JAVA_HOME"

echo ""
echo "=================================================="
echo "STEP 2: Installing Flutter SDK"
echo "=================================================="
if [ ! -d "$HOME/flutter" ]; then
  cd "$HOME"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter already cloned at ~/flutter"
fi

# Add Flutter to PATH for this session AND permanently (future terminals)
export PATH="$HOME/flutter/bin:$PATH"
if ! grep -q 'flutter/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.bashrc"
fi

echo "Flutter version:"
flutter --version

echo ""
echo "=================================================="
echo "STEP 3: Installing Android SDK Command-Line Tools"
echo "=================================================="
export ANDROID_SDK_ROOT="$HOME/android-sdk"
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"

if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
  cd /tmp
  # Command-line tools "latest" package from Google (stable, small download)
  curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q cmdline-tools.zip -d cmdline-tools-extracted
  mv cmdline-tools-extracted/cmdline-tools "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf cmdline-tools.zip cmdline-tools-extracted
else
  echo "Android cmdline-tools already installed"
fi

# Add Android SDK tools to PATH for this session AND permanently
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
if ! grep -q 'ANDROID_SDK_ROOT' "$HOME/.bashrc"; then
  {
    echo "export ANDROID_SDK_ROOT=\"$HOME/android-sdk\""
    echo 'export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"'
  } >> "$HOME/.bashrc"
fi

echo ""
echo "=================================================="
echo "STEP 4: Installing required SDK packages"
echo "=================================================="
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0" > /dev/null

echo ""
echo "=================================================="
echo "STEP 5: Accepting Android SDK licenses"
echo "=================================================="
yes | flutter doctor --android-licenses > /dev/null || true
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses > /dev/null || true

echo ""
echo "=================================================="
echo "STEP 6: Telling Flutter where the Android SDK is"
echo "=================================================="
flutter config --android-sdk "$ANDROID_SDK_ROOT"

echo ""
echo "=================================================="
echo "STEP 7: flutter doctor (full diagnostic)"
echo "=================================================="
flutter doctor -v || true

echo ""
echo "=================================================="
echo "STEP 8: Building the debug APK"
echo "=================================================="
cd "$(dirname "$0")"  # run this script from inside tubepilot_flutter/
flutter clean
flutter pub get
flutter build apk --debug

echo ""
echo "=================================================="
echo "DONE! APK is at:"
echo "  build/app/outputs/flutter-apk/app-debug.apk"
echo "=================================================="
