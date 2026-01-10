#!/bin/sh
set -eu

BUCKET="rclone-macos:truenas-backup-mdemeczky"
CURRENT="${BUCKET}/current"
ARCHIVE="${BUCKET}/Archive"

DATE="$(date +%Y-%m-%d)"
TMP="/tmp/b2-current-items.txt"

echo
echo "Collecting inventory from current/ ..."
rclone lsf "$CURRENT" --max-depth 1 > "$TMP"

if [ ! -s "$TMP" ]; then
  echo "current/ is empty. Nothing to archive."
  exit 0
fi

echo
echo "Items in current/ (folders and root files):"
echo "-------------------------------------------"
nl -w2 -s') ' "$TMP"
echo

echo "Enter the NUMBER of the item to archive:"
read IDX

ITEM="$(sed -n "${IDX}p" "$TMP")"

if [ -z "$ITEM" ]; then
  echo "Invalid selection."
  exit 1
fi

# remove trailing slash for folders
ITEM_CLEAN="$(printf "%s" "$ITEM" | sed 's:/$::')"

SRC="${CURRENT}/${ITEM}"
DST="${ARCHIVE}/${ITEM_CLEAN}-${DATE}"

echo
echo "You selected:"
echo "  FROM: $SRC"
echo

