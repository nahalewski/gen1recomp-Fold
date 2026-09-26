#!/usr/bin/env bash
# Builds the G1R Fold APK: upstream gen1recomp's own Android app plus the
# fold3ds layer.  Needs the Android SDK (API 36, build-tools 36, NDK
# 25.2.9519653), a JDK, git and python3.  Output: build/aeondx-game/dist/android/debug/*.apk
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_COMMIT="${UPSTREAM_COMMIT:-c8b64177f60f94d8e052445f36fbd09550e73c48}"
mkdir -p "$HERE/build"
if [ ! -d "$HERE/build/aeondx-game/.git" ]; then
  git clone https://github.com/bryanthaboi/gen1recomp.git "$HERE/build/aeondx-game"
fi
cd "$HERE/build/aeondx-game"
git fetch -q origin "$UPSTREAM_COMMIT" 2>/dev/null || true
git checkout -q "$UPSTREAM_COMMIT"
J=mobile/android/love/src/jni/love/src
git checkout -q -- main.lua scripts/build_android.sh src/import/LauncherView.lua \
  $J/modules/system/System.cpp $J/modules/system/wrap_System.cpp \
  $J/common/android.h $J/common/android.cpp \
  mobile/android/app/src/main/AndroidManifest.xml mobile/android/app/proguard-rules.pro \
  mobile/android/app/build.gradle mobile/android/love/build.gradle \
  mobile/android/love/src/main/java/org/love2d/android/GameActivity.java
# the launcher's compact bottom-screen layout (active only under LauncherView.fold),
# the Android picker's "image" kind (the cover sticker), and the camera bridge
# (love.system.foldCamera -> FoldCamera / FoldRecorder / FoldBridge / FoldPlay:
# the Camera applet, the volume slider's keys, Download Play)
for p in "$HERE"/patches/*.patch; do git apply --recount "$p" || git apply "$p"; done
cp "$HERE"/android/*.java mobile/android/love/src/main/java/org/love2d/android/
# FoldBridge's "hinge" reads Jetpack WindowManager's FoldingFeature (where the fold
# is, flat/half-open) - the 3DS XL hinge. Added once; build.gradle is reset above.
grep -q "androidx.window:window-java" mobile/android/love/build.gradle \
  || printf '\ndependencies {\n    implementation "androidx.window:window-java:1.2.0"\n}\n' >> mobile/android/love/build.gradle
# the layer
rm -rf fold3ds && cp -r "$HERE/fold3ds" fold3ds
# the community mod catalog (gen1recomp.com/mod) as of this build: shipped so
# FIND lists every mod before the first live fetch.  Keeps the committed copy
# when offline.
python3 - <<'PY2' || true
import json, urllib.request
url = "https://raw.githubusercontent.com/bryanthaboi/gen1recomp-mod-index/main/site/data/index.json"
try:
    body = urllib.request.urlopen(url, timeout=30).read()
    doc = json.loads(body)
    assert doc.get("schema_version") == 1 and isinstance(doc.get("mods"), list)
    open("fold3ds/modindex/index.json", "wb").write(body)
    print("mod catalog: %d mods" % len(doc["mods"]))
except Exception as e:
    print("mod catalog: keeping the bundled copy (%s)" % e)
PY2
# hook it into main.lua (last lines) and package it into game.love
printf '\n-- the AeonDX layer (fold3ds/): 3DS UI is the default\nlocal _ok, _err = pcall(function() require("fold3ds").install() end)\nif not _ok then print("fold3ds install error: " .. tostring(_err)) end\n' >> main.lua
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("scripts/build_android.sh"); s = p.read_text()
# the Camera applet records video with sound: keep the microphone permission
s = s.replace('    "android.permission.RECORD_AUDIO",\n', "")
s = s.replace("main.lua conf.lua src data assets tools/save-editor \\", "main.lua conf.lua src data assets fold3ds tools/save-editor \\")
s = s.replace("-x 'data/generated/*' -x 'assets/generated/*')", "-x 'data/generated/*' -x 'assets/generated/*' -x 'fold3ds/dev/*' -x 'fold3ds/homesprites/*')")
p.write_text(s)
PY
export GEN1RECOMP_ANDROID_APPLICATION_ID="${GEN1RECOMP_ANDROID_APPLICATION_ID:-com.nahalewski.aeondx}"
export GEN1RECOMP_ANDROID_APP_NAME="${GEN1RECOMP_ANDROID_APP_NAME:-AeonDX}"
bash scripts/build_android.sh "$@"
