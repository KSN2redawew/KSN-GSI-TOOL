#!/usr/bin/env bash
set -euo pipefail

ROOT=${ROOT:?}
WORK=${WORK:?}

# Читаем аргументы, переданные из gsi.sh
SUPER="${1:-}"
ROMZIP="${2:-}"

TOOLS="$ROOT/tools"
SIMG2IMG="${SIMG2IMG:-simg2img}"
LPUNPACK="${LPUNPACK:-$TOOLS/lpunpack}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

mkdir -p "$WORK"

if [[ -n "${ROMZIP:-}" ]]; then
    log "Extracting ROM zip..."
    mkdir -p "$WORK/rom"
    unzip -q "$ROMZIP" -d "$WORK/rom"
    # Ищем super / payload
    if [[ -f "$WORK/rom/super.img" ]]; then
        SUPER="$WORK/rom/super.img"
    elif [[ -f "$WORK/rom/payload.bin" ]]; then
        log "Found payload.bin, please use payload-dumper-go manually for now."
        exit 1
    fi
fi

if [[ -z "${SUPER:-}" ]]; then
    echo "No super.img found."
    exit 1
fi

SUPER="$(readlink -f "$SUPER")"
log "Processing super: $SUPER"

# Sparse -> Raw
RAW_SUPER="$WORK/super.raw.img"
log "Converting/Checking sparse image..."
if ! "$SIMG2IMG" "$SUPER" "$RAW_SUPER" 2>/dev/null; then
    # Если simg2img упал, скорее всего это уже raw, просто копируем
    cp "$SUPER" "$RAW_SUPER"
fi

# Unpack
UNPACK="$WORK/unpacked"
mkdir -p "$UNPACK"
log "Unpacking super partitions..."
"$LPUNPACK" "$RAW_SUPER" "$UNPACK"

# Функция поиска и копирования
find_copy() {
    local name="$1"
    local out="$2"
    for cand in "${name}_a.img" "${name}_b.img" "${name}.img"; do
        if [[ -f "$UNPACK/$cand" ]]; then
            cp "$UNPACK/$cand" "$WORK/$out"
            return 0
        fi
    done
}

# Копируем всё важное для GSI
find_copy "system" "system.img"
find_copy "system_ext" "system_ext.img"
find_copy "product" "product.img"
find_copy "vendor" "vendor.img"
find_copy "odm" "odm.img"
find_copy "mi_ext" "mi_ext.img"  # Xiaomi specific

log "Extraction done."
