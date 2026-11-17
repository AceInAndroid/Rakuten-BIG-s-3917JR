#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
BT=$SDK/build-tools/35.0.0
ANDROID_JAR=$SDK/platforms/android-35/android.jar
KEYSTORE=${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}
BUILD=$ROOT/.build
DIST=$ROOT/dist

mkdir -p "$BUILD/classes" "$BUILD/dex" "$DIST"
javac --release 8 -cp "$ANDROID_JAR" -d "$BUILD/classes" \
    "$ROOT/app/src/com/aceinandroid/rakutenbigs/batterylimit/MainActivity.java"
"$BT/d8" --min-api 29 --lib "$ANDROID_JAR" --output "$BUILD/dex" \
    "$BUILD/classes"/com/aceinandroid/rakutenbigs/batterylimit/*.class
"$BT/aapt" package -f -M "$ROOT/app/AndroidManifest.xml" -I "$ANDROID_JAR" \
    -F "$BUILD/unsigned.apk"
(cd "$BUILD/dex" && "$BT/aapt" add "$BUILD/unsigned.apk" classes.dex)
"$BT/zipalign" -f 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android \
    --key-pass pass:android --out "$DIST/3917jr-battery-limit.apk" "$BUILD/aligned.apk"
"$BT/apksigner" verify "$DIST/3917jr-battery-limit.apk"
rm -f "$DIST/3917jr-battery-limit-magisk.zip"
(cd "$ROOT/module" && zip -q -r "$DIST/3917jr-battery-limit-magisk.zip" .)
printf 'APK: %s\nModule: %s\n' "$DIST/3917jr-battery-limit.apk" "$DIST/3917jr-battery-limit-magisk.zip"
