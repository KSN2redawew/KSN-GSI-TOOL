#!/usr/bin/env bash
set -euo pipefail
ROOT=${ROOT:?}
WORK=${WORK:?}
. "$WORK/env.sh"

log() { echo "[$(date +%H:%M:%S)] $*"; }

SYSTEM_DIR="$WORK/system_root"
mkdir -p "$SYSTEM_DIR"

# Функция для монтирования образа (auto ext4/erofs)
mount_img() {
    local img="$1"
    local mnt="$2"
    mkdir -p "$mnt"
    
    # Сначала пробуем sparse->raw конверт (если нужно)
    local raw="$img.raw"
    simg2img "$img" "$raw" 2>/dev/null || cp "$img" "$raw"
    
    # Пробуем ext4
    if sudo mount -o loop,ro "$raw" "$mnt" 2>/dev/null; then
        return 0
    fi
    # Пробуем erofs
    if sudo mount -t erofs -o loop,ro "$raw" "$mnt" 2>/dev/null; then
        return 0
    fi
    return 1
}

# 1. Разворачиваем SYSTEM (база)
log "Extracting SYSTEM base..."
MNT_SYS="$WORK/mnt_system"
if mount_img "$WORK/system.img" "$MNT_SYS"; then
    # Копируем всё в RW папку
    sudo rsync -aHAX "$MNT_SYS/" "$SYSTEM_DIR/"
    sudo umount "$MNT_SYS"
else
    log "Failed to mount system.img! Check if it is valid."
    exit 1
fi

# 2. Функция слияния (Merge)
merge_part() {
    local name="$1"
    local target="$2"  # путь внутри system (напр. system/product)
    
    local img="$WORK/${name}.img"
    if [[ -f "$img" ]]; then
        log "Merging $name -> $target..."
        local mnt="$WORK/mnt_${name}"
        if mount_img "$img" "$mnt"; then
            local dest_path="$SYSTEM_DIR/$target"
            
            # Если по пути назначения есть симлинк или файл — удаляем его,
            # чтобы создать папку для слияния
            if [[ -L "$dest_path" || -f "$dest_path" ]]; then
                sudo rm -f "$dest_path"
            fi
            
            mkdir -p "$dest_path"
            sudo rsync -aHAX "$mnt/" "$dest_path/"
            sudo umount "$mnt"
        else
            log "Failed to mount $name"
        fi
    fi
}

# 3. Сливаем разделы
# Структура GSI (Android 10+ SAR):
# /system_root/system/system_ext
# /system_root/system/product
# ...
merge_part "system_ext" "system/system_ext"
merge_part "product"    "system/product"
merge_part "mi_ext"     "system/mi_ext"
merge_part "odm"        "system/odm"

# 4. Запуск патчей
log "Running patches..."
run_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    for f in "$dir"/*.sh; do
        [[ -x "$f" ]] || continue
        log "Patch: $(basename "$f")"
        SYSTEM_DIR="$SYSTEM_DIR" OEM="$OEM" bash "$f"
    done
}

run_dir "$ROOT/patches/common"
run_dir "$ROOT/patches/$OEM"

log "Patches & Merge done."
