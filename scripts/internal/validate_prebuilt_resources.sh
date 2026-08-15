#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Validates repository-pinned prebuilt inputs and extracted SELinux metadata
# before a device build starts.

set -euo pipefail

SRC_DIR="${SRC_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    echo "Usage: validate_prebuilt_resources <target>" >&2
    exit 1
fi

LOCK_FILE="$SRC_DIR/target/$TARGET/prebuilts.lock"
if [ ! -f "$LOCK_FILE" ]; then
    echo "No prebuilt lock file for target: $TARGET" >&2
    exit 1
fi

PREBUILT_DIRS=()

validate_pinned_prebuilts()
{
    local device expected current prebuilt_dir

    while IFS='=' read -r device expected; do
        [ -z "$device" ] && continue
        [[ "$device" == \#* ]] && continue

        prebuilt_dir="$SRC_DIR/prebuilts/samsung/$device"
        if [ ! -d "$prebuilt_dir" ]; then
            echo "Missing required prebuilt directory: prebuilts/samsung/$device" >&2
            exit 1
        fi
        if [ ! -f "$prebuilt_dir/.current" ]; then
            echo "Missing version anchor: prebuilts/samsung/$device/.current" >&2
            exit 1
        fi

        current="$(cat "$prebuilt_dir/.current")"
        if [ "$current" != "$expected" ]; then
            echo "Pinned prebuilt version mismatch for $device" >&2
            echo "  expected: $expected" >&2
            echo "  actual:   $current" >&2
            exit 1
        fi

        PREBUILT_DIRS+=("$prebuilt_dir")
        echo "Validated pinned prebuilt: $device ($current)"
    done < "$LOCK_FILE"
}

validate_file_context_file()
{
    local context_file="$1"

    if ! awk -v file="$context_file" '
        NF != 2 {
            printf "%s:%d: expected <path> <selinux-context>; got %d field(s)\\n", file, NR, NF > "/dev/stderr"
            invalid = 1
        }
        END { exit invalid }
    ' "$context_file"; then
        echo "Invalid file context metadata: $context_file" >&2
        exit 1
    fi
}

validate_fs_config_file()
{
    local config_file="$1"

    if ! awk -v file="$config_file" '
        NF < 4 {
            printf "%s:%d: expected <uid> <gid> <mode> [capabilities] with an optional path; got %d field(s)\\n", file, NR, NF > "/dev/stderr"
            invalid = 1
        }
        END { exit invalid }
    ' "$config_file"; then
        echo "Invalid fs_config metadata: $config_file" >&2
        exit 1
    fi
}

validate_file_contexts()
{
    local context_file prebuilt_dir

    for prebuilt_dir in "${PREBUILT_DIRS[@]}"; do
        while IFS= read -r -d '' context_file; do
            validate_file_context_file "$context_file"
        done < <(find "$prebuilt_dir" -type f -name 'file_context-*' -print0)
    done

    [ -d "$SRC_DIR/out/fw" ] || return 0

    while IFS= read -r -d '' context_file; do
        validate_file_context_file "$context_file"
    done < <(find "$SRC_DIR/out/fw" -type f -name 'file_context-*' -print0)
}

validate_fs_configs()
{
    local config_file prebuilt_dir

    for prebuilt_dir in "${PREBUILT_DIRS[@]}"; do
        while IFS= read -r -d '' config_file; do
            validate_fs_config_file "$config_file"
        done < <(find "$prebuilt_dir" -type f -name 'fs_config-*' -print0)
    done

    [ -d "$SRC_DIR/out/fw" ] || return 0

    while IFS= read -r -d '' config_file; do
        validate_fs_config_file "$config_file"
    done < <(find "$SRC_DIR/out/fw" -type f -name 'fs_config-*' -print0)
}

validate_pinned_prebuilts
validate_file_contexts
validate_fs_configs

echo "Prebuilt resource validation completed for $TARGET"
