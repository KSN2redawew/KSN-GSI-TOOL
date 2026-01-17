#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/work/$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/out"
mkdir -p "$WORK" "$OUT"

SUPER=""
ROMZIP=""
BUILD_TYPE="ab"   # a|ab
TARGET_OEM="auto" # miui/oneui/oos/hyperos/generic/auto

usage() {
    echo "Usage:"
    echo "  $0 --super super.img [--type a|ab] [--oem auto|miui|oneui|oos|hyperos|generic]"
    echo "  $0 --rom rom.zip     [--type a|ab] [--oem auto|miui|oneui|oos|hyperos|generic]"
    exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --super) SUPER="$2"; shift 2 ;;
    --rom)   ROMZIP="$2"; shift 2 ;;
    --type)  BUILD_TYPE="$2"; shift 2 ;;
    --oem)   TARGET_OEM="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$SUPER" || -n "$ROMZIP" ]] || usage

if [[ -n "$SUPER" ]]; then
    SUPER="$(readlink -f "$SUPER")"
fi
if [[ -n "$ROMZIP" ]]; then
    ROMZIP="$(readlink -f "$ROMZIP")"
fi
# ====================================

# === Banner ===
BLUE="\e[34m"
WHITE="\e[97m"
RED="\e[31m"
RESET="\e[0m"

clear
printf "${BLUE}"
cat << "EOF"
 _  __ ____   _   _    ____  ____  ___   _____  ___    ___   _     
| |/ // ___| | \ | |  / ___|/ ___||_ _| |_   _|/ _ \  / _ \ | |    
| ' / \___ \ |  \| | | |  _ \___ \ | |    | | | | | || | | || |    
| . \  ___) || |\  | | |_| | ___) || |    | | | |_| || |_| || |___ 
|_|\_\|____/ |_| \_|  \____||____/|___|   |_|  \___/  \___/ |_____|
EOF
printf "${RESET}"

# Красное предупреждение
printf "${RED}\n"
echo "WARNING: This is an experimental TEST build."
echo "Patches are NOT finished yet. Resulting GSIs may be unstable or fail to boot."
printf "${RESET}\n"

# Белый описательный текст
printf "${WHITE}\n"
echo "KSNGSITOOL - Universal OEM-to-GSI Builder"
echo
echo "Build powerful Generic System Images from OEM firmware in one command."
echo "Dynamic partitions, automatic OEM detection, modular patch profiles — WIP."
printf "${RESET}\n"

# === Resolve input source for prompt ===
SRC_LABEL=""
if [[ -n "$SUPER" ]]; then
    SRC_LABEL="$SUPER"
elif [[ -n "$ROMZIP" ]]; then
    SRC_LABEL="$ROMZIP"
else
    echo "No input specified. Use --super super.img or --rom rom.zip"
    exit 1
fi

printf "${WHITE}Do you want to port from \"${SRC_LABEL}\"? [Y/n]: ${RESET}"
read -r REPLY
REPLY=${REPLY:-Y}

case "$REPLY" in
    [Yy]*)
        echo "Starting KSNGSITOOL pipeline..."
        ;;
    *)
        echo "Aborted by user."
        exit 0
        ;;
esac
echo

export ROOT WORK OUT BUILD_TYPE TARGET_OEM

bash "$ROOT/core/extract.sh" "$SUPER" "$ROMZIP"
bash "$ROOT/core/detect.sh"
bash "$ROOT/core/patch_runner.sh"
bash "$ROOT/core/build_system.sh"
bash "$ROOT/core/info.sh"
