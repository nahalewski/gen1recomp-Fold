#!/usr/bin/env bash
# Build a single-file Flatpak bundle for x86_64 desktop Linux.
#
# Usage: scripts/build_flatpak.sh [--version X.Y.Z] [--game-love PATH]
#
# Output:
#   dist/flatpak/gen1recomp-<version>-linux.flatpak
#
# Requires: flatpak, flatpak-builder, and network on first run (Freedesktop
# runtime + LÖVE AppImage download).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="com.theboisclub.gen1recomp"
VERSION="0.0.0"
GAME_LOVE_IN=""
DIST="$ROOT/dist/flatpak"
BUILD_DIR="$ROOT/.bazinga/flatpak-build"
REPO_DIR="$ROOT/.bazinga/flatpak-repo"
STATE_DIR="$ROOT/.bazinga/flatpak-state"
CACHE="$ROOT/.bazinga/flatpak-cache"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift ;;
    --game-love) GAME_LOVE_IN="$2"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "invalid --version '$VERSION' (expected X.Y.Z)"
fi

command -v flatpak >/dev/null || fail "flatpak not found"
command -v flatpak-builder >/dev/null || fail "flatpak-builder not found"

mkdir -p "$DIST" "$BUILD_DIR" "$REPO_DIR" "$STATE_DIR" "$CACHE"

LOVE_FILE="$CACHE/game.love"
if [ -n "$GAME_LOVE_IN" ]; then
  [ -f "$GAME_LOVE_IN" ] || fail "game.love not found: $GAME_LOVE_IN"
  if [ "$(readlink -f "$GAME_LOVE_IN")" != "$(readlink -f "$LOVE_FILE")" ]; then
    cp "$GAME_LOVE_IN" "$LOVE_FILE"
  fi
else
  say "packing game.love"
  "$ROOT/scripts/pack_love.sh" --output "$LOVE_FILE" --version "$VERSION"
fi

# Stage local sources next to the generated manifest (flatpak path: is relative).
cp "$ROOT/flatpak/$APP_ID.desktop" "$CACHE/$APP_ID.desktop"
# AppStream rejects icons larger than the declared hicolor size.
if command -v magick >/dev/null 2>&1; then
  magick "$ROOT/assets/logo/gen1recomp_cover.png" -resize 512x512 "$CACHE/icon.png"
elif command -v convert >/dev/null 2>&1; then
  convert "$ROOT/assets/logo/gen1recomp_cover.png" -resize 512x512 "$CACHE/icon.png"
else
  fail "need ImageMagick (magick/convert) to resize the Flatpak icon to 512x512"
fi


DATE="$(date -u +%Y-%m-%d)"
python3 - "$ROOT/flatpak/$APP_ID.metainfo.xml" "$CACHE/$APP_ID.metainfo.xml" "$VERSION" "$DATE" <<'PY'
import sys, pathlib, re
src, dst, ver, date = sys.argv[1:5]
text = pathlib.Path(src).read_text(encoding="utf-8")
release = f'    <release version="{ver}" date="{date}"/>'
text = re.sub(
    r"<releases>.*?</releases>",
    "<releases>\n" + release + "\n  </releases>",
    text,
    count=1,
    flags=re.S,
)
pathlib.Path(dst).write_text(text, encoding="utf-8")
PY

BRIDGE_LIB="liblibrashader_bridge.so"
BRIDGE_SRC="${SHADERFX_BRIDGE_LINUX_X64:-}"
if [ -z "$BRIDGE_SRC" ] && [ -f "$ROOT/dist/native/linux-x64/$BRIDGE_LIB" ]; then
  BRIDGE_SRC="$ROOT/dist/native/linux-x64/$BRIDGE_LIB"
fi
if [ -z "$BRIDGE_SRC" ] && [ -f "$ROOT/tools/shaderfx-bridge/target/release/$BRIDGE_LIB" ]; then
  BRIDGE_SRC="$ROOT/tools/shaderfx-bridge/target/release/$BRIDGE_LIB"
fi
rm -f "$CACHE/$BRIDGE_LIB"
if [ -n "$BRIDGE_SRC" ] && [ -f "$BRIDGE_SRC" ]; then
  cp "$BRIDGE_SRC" "$CACHE/$BRIDGE_LIB"
  cp "$ROOT/flatpak/$APP_ID.yml" "$CACHE/$APP_ID.yml"
  say "staged $BRIDGE_LIB for SHADER FX preset conversion"
elif [ "${SHADERFX_BRIDGE_REQUIRED:-}" = "1" ]; then
  fail "$BRIDGE_LIB not found: set SHADERFX_BRIDGE_LINUX_X64 or stage it at dist/native/linux-x64/$BRIDGE_LIB"
else
  warn "$BRIDGE_LIB not found: this bundle can run converted presets but not CONVERT new ones"
  sed '/# BRIDGE-BEGIN/,/# BRIDGE-END/d' "$ROOT/flatpak/$APP_ID.yml" > "$CACHE/$APP_ID.yml"
fi

say "installing Freedesktop runtime (no-op if present)"
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
flatpak --user install -y flathub \
  org.freedesktop.Platform//24.08 \
  org.freedesktop.Sdk//24.08 \
  || warn "runtime install reported an error; flatpak-builder may still reuse cache"

say "building Flatpak ($APP_ID $VERSION)"
# Run from CACHE so path: sources resolve.
(
  cd "$CACHE"
  flatpak-builder --user --force-clean \
    --state-dir="$STATE_DIR" \
    --repo="$REPO_DIR" \
    "$BUILD_DIR" "$APP_ID.yml"
)

OUT="$DIST/gen1recomp-${VERSION}-linux.flatpak"
rm -f "$OUT"
say "exporting bundle $OUT"
flatpak build-bundle "$REPO_DIR" "$OUT" "$APP_ID" \
  --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
chmod 644 "$OUT"
if command -v sha256sum >/dev/null 2>&1; then
  printf '%s  %s\n' "$(sha256sum "$OUT" | awk '{print $1}')" "$(basename "$OUT")" > "$OUT.sha256"
else
  printf '%s  %s\n' "$(shasum -a 256 "$OUT" | awk '{print $1}')" "$(basename "$OUT")" > "$OUT.sha256"
fi
if [ -f "$CACHE/$BRIDGE_LIB" ]; then
  [ -f "$BUILD_DIR/files/share/gen1recomp/$BRIDGE_LIB" ] \
    || fail "$BRIDGE_LIB was staged but is missing from the built /app/share/gen1recomp"
  say "verified $BRIDGE_LIB in the Flatpak"
fi
say "Flatpak build: $OUT ($(du -h "$OUT" | cut -f1))"
say "sha256: $(cut -d' ' -f1 "$OUT.sha256")"
