#!/usr/bin/env bash
set -euo pipefail
: "${SYSTEM_DIR:?}"


if [[ -f "$SYSTEM_DIR/system/build.prop" ]]; then
    echo "# by KSNgsitool" >> "$SYSTEM_DIR/system/build.prop"
fi
