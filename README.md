# KSNGSITOOL

KSNGSITOOL is an **experimental** OEM‑to‑GSI builder for Linux.  
It unpacks `super.img` or full ROM zips, merges dynamic partitions (`system_ext`, `product`, `mi_ext`) and builds Treble‑compatible GSI images (ext4 / EROFS) with modular patch profiles. [conversation_history:3]

> ⚠️ WARNING: This is a **test build**.  
> Patches are incomplete and resulting GSIs may be unstable or fail to boot. Use at your own risk.

## Features

- Automatic extraction of `super.img` (sparse/raw) via `simg2img` + `lpunpack`. [conversation_history:3]
- Merge of `system`, `system_ext`, `product`, `mi_ext`, `odm` into a single GSI system tree. [conversation_history:3]
- Basic OEM auto‑detection (generic/MIUI/HyperOS/etc.) via `build.prop`. [conversation_history:3]
- EROFS or ext4 sparse image generation for `Generic-AB-XX-KSNGSITOOL.img`. [conversation_history:3]
- Modular patch system: `patches/common`, `patches/<oem>` (e.g. `miui`, `transsion`). [conversation_history:3]
- Info summary after build (Android version, build number, fingerprint, size, etc.). [conversation_history:3]

## Requirements

- Linux (tested on Ubuntu/Debian).
- Root access (for mounting images).
- Packages:
  - `android-sdk-libsparse-utils` (`simg2img`, `img2simg`)
  - `erofs-utils` (`mkfs.erofs`)
  - `unzip`, `coreutils`, `rsync` [conversation_history:3]
