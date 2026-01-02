#!/bin/sh
set -eu

BUCKET="backblaze:truenas-backup-mdemeczky"
SRC_BASE="${BUCKET}/current"
DST_BASE="${BUCKET}/Archive"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <folder-or-prefix-in-current>" >&2
  echo "Example: $0 Flickr-backup-2025" >&2
  exit 2
fi

NAME="$1"

SRC="${SRC_BASE}/${NAME}/"
DST="${DST_BASE}/${NAME}/"

# Dry-run first (recommended) - remove --dry-run when you're happy
rclone move "$SRC" "$DST" --progress --dry-run

