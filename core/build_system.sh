#!/usr/bin/env bash
set -euo pipefail
ROOT=${ROOT:?}
WORK=${WORK:?}
OUT=${OUT:?}
. "$WORK/env.sh"

log() { echo "[$(date +%H:%M:%S)] $*"; }

SYSTEM_DIR="$WORK/system_root"
OUT_IMG="$OUT/Generic-${BUILD_TYPE}-${ANDROID_VER:-16}-KSNGSITOOL.img"
MKFS_EROFS="${MKFS_EROFS:-mkfs.erofs}"

log "Building final image..."

# Пытаемся найти file_contexts в системе (нужен для корректного SELinux)
FILE_CONTEXTS=""
# В Android 10+ он обычно тут:
FC_PATH="$SYSTEM_DIR/system/etc/selinux/plat_file_contexts"
if [[ -f "$FC_PATH" ]]; then
    FILE_CONTEXTS="--file-contexts=$FC_PATH"
fi

# Если mkfs.erofs есть - используем его
if command -v "$MKFS_EROFS" &>/dev/null; then
    log "Using EROFS compression..."
    
    # Убираем --mount-point, так как версия 1.4 его не знает.
    # Добавляем --all-root (чтобы права были root) и -T0 (детерминизм)
    
    # Попытка 1: Сжимаем папку system внутри system_root
    if ! "$MKFS_EROFS" -zlz4hc -T0 --all-root $FILE_CONTEXTS "$OUT_IMG" "$SYSTEM_DIR/system"; then
        # Попытка 2: Если не вышло, сжимаем корень
        "$MKFS_EROFS" -zlz4hc -T0 --all-root $FILE_CONTEXTS "$OUT_IMG" "$SYSTEM_DIR"
    fi
else
    # Fallback to Ext4
    log "mkfs.erofs not found! Using Ext4..."
    DU_SIZE=$(du -sm "$SYSTEM_DIR" | cut -f1)
    SIZE_MB=$((DU_SIZE + 500))
    
    RAW_TMP="$WORK/sys_raw.img"
    truncate -s "${SIZE_MB}M" "$RAW_TMP"
    mke2fs -t ext4 -F -L system "$RAW_TMP"
    
    MNT="$WORK/mnt_build"
    mkdir -p "$MNT"
    sudo mount -o loop "$RAW_TMP" "$MNT"
    sudo rsync -aHAX "$SYSTEM_DIR/" "$MNT/"
    sudo umount "$MNT"
    
    img2simg "$RAW_TMP" "$OUT_IMG"
    rm "$RAW_TMP"
fi

log "Done: $OUT_IMG"
