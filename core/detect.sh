#!/usr/bin/env bash
set -euo pipefail

# Если скрипт запущен не из gsi.sh — подставим значения по умолчанию
if [[ -z "${ROOT:-}" ]]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ -z "${WORK:-}" ]]; then
    # берём последний work-слот
    LAST_WORK="$(ls "$ROOT/work" 2>/dev/null | sort | tail -n1 || true)"
    if [[ -z "$LAST_WORK" ]]; then
        echo "WORK is not set and no work/* directories found"
        exit 1
    fi
    WORK="$ROOT/work/$LAST_WORK"
fi

if [[ -z "${BUILD_TYPE:-}" ]]; then
    BUILD_TYPE="ab"
fi

if [[ -z "${TARGET_OEM:-}" ]]; then
    TARGET_OEM="auto"
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }

SYSTEM_IMG="$WORK/system.img"
if [[ ! -f "$SYSTEM_IMG" ]]; then
    echo "system.img missing at $SYSTEM_IMG"
    exit 1
fi

MNT="$WORK/mnt_system"
mkdir -p "$MNT"

log "Mounting system.img for detect..."
if ! sudo mount -o loop,ro "$SYSTEM_IMG" "$MNT" 2>/dev/null; then
    echo "mount failed"
    exit 1
fi

BUILD_PROP=""
if [[ -f "$MNT/system/build.prop" ]]; then
    BUILD_PROP="$MNT/system/build.prop"
elif [[ -f "$MNT/build.prop" ]]; then
    BUILD_PROP="$MNT/build.prop"
fi

OEM="generic"
ANDROID_VER=""
VNDK=""

if [[ -n "$BUILD_PROP" ]]; then
    ANDROID_VER="$(grep -m1 'ro.build.version.release=' "$BUILD_PROP" | cut -d= -f2- || true)"
    VNDK="$(grep -m1 'ro.vndk.version=' "$BUILD_PROP" | cut -d= -f2- || true)"

    if grep -q 'ro.miui.ui.version' "$BUILD_PROP"; then
        OEM="miui"
    elif grep -q 'ro.build.version.oneui' "$BUILD_PROP"; then
        OEM="oneui"
    elif grep -q 'ro.oxygen.version' "$BUILD_PROP"; then
        OEM="oos"
    fi
fi

sudo umount "$MNT" || true

if [[ "$TARGET_OEM" != "auto" ]]; then
    OEM="$TARGET_OEM"
fi

log "Detected Android: ${ANDROID_VER:-unknown} VNDK: ${VNDK:-none} OEM: $OEM Type: $BUILD_TYPE"

# сохраним в файл env, чтобы другие скрипты могли заюзать
cat > "$WORK/env.sh" <<EOF
export OEM="$OEM"
export ANDROID_VER="$ANDROID_VER"
export VNDK="$VNDK"
export BUILD_TYPE="$BUILD_TYPE"
EOF
