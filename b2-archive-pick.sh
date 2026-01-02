#!/bin/sh
# Interactive B2 Archive Picker – TrueNAS CORE SAFE
# - single instance (lockf)
# - guaranteed visible menu
# - no spaces in destination
# - dry-run first

set -eu

LOCKFILE="/var/run/b2-archive-pick.lock"

# Must be interactive
if [ ! -t 0 ]; then
  echo "This script requires an interactive terminal." >&2
  exit 2
fi

# Lock the whole script
if [ -z "${B2_ARCHIVE_LOCKED:-}" ]; then
  export B2_ARCHIVE_LOCKED=1
  exec lockf -t 0 "$LOCKFILE" /bin/sh "$0" "$@"
fi

REMOTE="backblaze"
BUCKET_NAME="truenas-backup-mdemeczky"
BUCKET="${REMOTE}:${BUCKET_NAME}"

CURRENT="${BUCKET}/current"
ARCHIVE="${BUCKET}/Archive"
DATE="$(date +%Y-%m-%d)"

TMP="/tmp/b2-current-root-items.txt"

RCLONE_COMMON="--contimeout 20s --timeout 2m --retries 3 --low-level-retries 3"

say() { echo "$*"; }

# -------- build list --------
: > "$TMP"

say "Listing folders in current/ ..."
rclone lsf "$CURRENT" --dirs-only --max-depth 1 $RCLONE_COMMON 2>/dev/null \
  | sed 's:/$::' >> "$TMP" || true

say "Listing files in current/ ..."
rclone lsf "$CURRENT" --files-only --max-depth 1 $RCLONE_COMMON 2>/dev/null \
  >> "$TMP" || true

if [ ! -s "$TMP" ]; then
  say "current/ root is empty. Nothing to archive."
  exit 0
fi

# -------- menu --------
echo
echo "Items in current/ (root only):"
echo "-----------------------------"
nl -w2 -s') ' "$TMP"
echo

while :; do
  echo -n "Choose a NUMBER to archive (or 'q' to quit): "
  read ans

  case "$ans" in
    q|Q) exit 0 ;;
    ''|*[!0-9]*)
      echo "Please enter a valid number."
      ;;
    *)
      ITEM="$(sed -n "${ans}p" "$TMP" | tr -d '\r')"
      if [ -n "$ITEM" ]; then
        break
      else
        echo "Invalid selection."
      fi
      ;;
  esac
done

ITEM_SAFE="$(echo "$ITEM" | tr ' ' '_')"

SRC="${CURRENT}/${ITEM}"
DST="${ARCHIVE}/${ITEM_SAFE}-${DATE}"

echo
echo "Selected:"
echo " FROM: $SRC"
echo " TO:   $DST"
echo

echo "1) DRY-RUN"
rclone move "$SRC" "$DST" $RCLONE_COMMON --dry-run --progress

echo
echo -n "Type MOVE to proceed: "
read confirm

[ "$confirm" = "MOVE" ] || { echo "Cancelled."; exit 0; }

echo
echo "2) REAL MOVE"
rclone move "$SRC" "$DST" $RCLONE_COMMON --progress

echo "Done."

