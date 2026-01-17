#!/usr/bin/env bash
set -euo pipefail

OUT=${OUT:?}
WORK=${WORK:?}

# Подтягиваем env (OEM, BUILD_TYPE, ANDROID_VER)
if [[ -f "$WORK/env.sh" ]]; then
  . "$WORK/env.sh"
fi

BUILD_TYPE="${BUILD_TYPE:-ab}"

# Ищем последний собранный образ KSNGSITOOL
OUT_IMG="$(ls "$OUT"/Generic-"$BUILD_TYPE"-*KSNGSITOOL.img 2>/dev/null | tail -n1 || true)"

if [[ -z "$OUT_IMG" || ! -f "$OUT_IMG" ]]; then
  echo "Output image not found (Generic-${BUILD_TYPE}-*KSNGSITOOL.img)"
  exit 1
fi

RAW_IMG="$WORK/info_raw.img"
SIMG2IMG="${SIMG2IMG:-simg2img}"

# Пытаемся sparse -> raw; если файл уже RAW/EROFS, simg2img упадёт, тогда просто копируем
if ! $SIMG2IMG "$OUT_IMG" "$RAW_IMG" 2>/dev/null; then
  cp "$OUT_IMG" "$RAW_IMG"
fi

MNT="$WORK/mnt_info"
mkdir -p "$MNT"

# Пытаемся смонтировать как ext4, если нет — как erofs
if sudo mount -o loop,ro "$RAW_IMG" "$MNT" 2>/dev/null; then
    :
elif sudo mount -t erofs -o loop,ro "$RAW_IMG" "$MNT" 2>/dev/null; then
    :
else
  echo "mount failed (unknown fs), skip info"
  rm -f "$RAW_IMG"
  exit 0
fi

BUILD_PROP=""
if [[ -f "$MNT/system/build.prop" ]]; then
    BUILD_PROP="$MNT/system/build.prop"
elif [[ -f "$MNT/build.prop" ]]; then
    BUILD_PROP="$MNT/build.prop"
fi

ANDROID_VERSION=""
BRAND=""
MODEL=""
CODENAME=""
BUILD_TYPE_STR=""
BUILD_NUMBER=""
INCREMENTAL=""
TAGS=""
SEC_PATCH=""
FINGERPRINT=""
BUILD_DATE=""
BUILD_DATE_UTC=""

if [[ -n "$BUILD_PROP" ]]; then
  ANDROID_VERSION=$(grep -m1 '^ro.build.version.release=' "$BUILD_PROP" | cut -d= -f2- || true)
  BRAND=$(grep -m1 '^ro.product.brand=' "$BUILD_PROP" | cut -d= -f2- || true)
  MODEL=$(grep -m1 '^ro.product.model=' "$BUILD_PROP" | cut -d= -f2- || true)
  CODENAME=$(grep -m1 '^ro.product.device=' "$BUILD_PROP" | cut -d= -f2- || true)
  BUILD_TYPE_STR=$(grep -m1 '^ro.build.type=' "$BUILD_PROP" | cut -d= -f2- || true)
  BUILD_NUMBER=$(grep -m1 '^ro.build.id=' "$BUILD_PROP" | cut -d= -f2- || true)
  INCREMENTAL=$(grep -m1 '^ro.build.version.incremental=' "$BUILD_PROP" | cut -d= -f2- || true)
  TAGS=$(grep -m1 '^ro.build.tags=' "$BUILD_PROP" | cut -d= -f2- || true)
  SEC_PATCH=$(grep -m1 '^ro.build.version.security_patch=' "$BUILD_PROP" | cut -d= -f2- || true)

  # Приоритет: ro.system.build.fingerprint (Pixel/cheetah), затем ro.build.fingerprint
  FINGERPRINT=$(grep -m1 '^ro.system.build.fingerprint=' "$BUILD_PROP" | cut -d= -f2- || true)
  if [[ -z "$FINGERPRINT" ]]; then
    FINGERPRINT=$(grep -m1 '^ro.build.fingerprint=' "$BUILD_PROP" | cut -d= -f2- || true)
  fi

  BUILD_DATE=$(grep -m1 '^ro.build.date=' "$BUILD_PROP" | cut -d= -f2- || true)
  BUILD_DATE_UTC=$(grep -m1 '^ro.build.date.utc=' "$BUILD_PROP" | cut -d= -f2- || true)
fi

sudo umount "$MNT" || true
rm -f "$RAW_IMG"

RAW_SIZE_BYTES=$(stat -c%s "$OUT_IMG")
SIZE_GIB=$(awk "BEGIN {printf \"%.2f\", $RAW_SIZE_BYTES/1024/1024/1024}")

echo
echo "Android Version: $ANDROID_VERSION"
echo "Brand: $BRAND"
echo "Model: $MODEL"
echo "Codename: $CODENAME"
echo "Build Type: $BUILD_TYPE_STR"
echo "Build Number: $BUILD_NUMBER"
echo "Incremental: $INCREMENTAL"
echo "Tags: $TAGS"
echo "Security Patch: $SEC_PATCH"
echo "Fingerprint: $FINGERPRINT"
echo "Build Date: $BUILD_DATE"
echo "Build Date UTC: $BUILD_DATE_UTC"
echo "Raw Image Size: ${SIZE_GIB} GiB"
