#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Synchronize target prebuilt lock files after a blobs workflow updates one
# repository-pinned prebuilt directory.

set -euo pipefail

SRC_DIR="${SRC_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
DEVICE="${1:-}"

if [ -z "$DEVICE" ]; then
    echo "Usage: sync_prebuilt_locks <prebuilt-device>" >&2
    exit 1
fi

CURRENT_FILE="$SRC_DIR/prebuilts/samsung/$DEVICE/.current"
if [ ! -f "$CURRENT_FILE" ]; then
    echo "Missing prebuilt version anchor: $CURRENT_FILE" >&2
    exit 1
fi

CURRENT="$(cat "$CURRENT_FILE")"
while IFS= read -r -d '' LOCK_FILE; do
    if grep -q "^${DEVICE}=" "$LOCK_FILE"; then
        sed -i "s|^${DEVICE}=.*|${DEVICE}=${CURRENT}|" "$LOCK_FILE"
        echo "Synchronized ${LOCK_FILE#$SRC_DIR/}: $DEVICE=$CURRENT"
    fi
done < <(find "$SRC_DIR/target" -type f -name prebuilts.lock -print0)
