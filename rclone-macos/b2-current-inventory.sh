#!/bin/sh
set -eu

BUCKET="rclone-macos:truenas-backup-mdemeczky"
CURRENT="${BUCKET}/current"

echo "=== current/ : ROOT FILES (max-depth 1) ==="
# List only files directly under current/
# (rclone lsf without --dirs-only lists both files and dirs; we filter out dirs)
rclone lsf "$CURRENT" --max-depth 1 2>/dev/null | awk '!/\/$/ {print}' || true

echo
echo "=== current/ : SUBFOLDERS ==="
rclone lsf "$CURRENT" --dirs-only 2>/dev/null || true

echo
echo "=== current/ : SIZE SUMMARY ==="
rclone size "$CURRENT" 2>/dev/null || true

