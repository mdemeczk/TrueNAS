#!/bin/sh
set -eu

REMOTE="${REMOTE:-backblaze}"
BUCKET_NAME="${BUCKET_NAME:-truenas-backup-mdemeczky}"
BUCKET="${REMOTE}:${BUCKET_NAME}"

CUR="${BUCKET}/current"
ARC="${BUCKET}/Archive"
DEL="${BUCKET}/deleted"

TMP="/tmp/b2-list-items.txt"
PICKED=""

say() { printf "%s\n" "$*"; }

list_root_prefixes() {
  say "=== BUCKET ROOT PREFIXES: ${BUCKET}/ ==="
  rclone lsf "$BUCKET" --dirs-only 2>/dev/null || true
}

list_path_depth1() {
  path="$1"
  title="$2"

  say
  say "=== ${title}: ${path}/ ==="
  say "--- ROOT FILES (depth 1) ---"
  rclone lsf "$path" --max-depth 1 2>/dev/null | awk '!/\/$/ {print}' || true

  say
  say "--- SUBFOLDERS (depth 1) ---"
  rclone lsf "$path" --dirs-only --max-depth 1 2>/dev/null || true

  say
  say "--- SIZE ---"
  rclone size "$path" 2>/dev/null || true
}

pick_subfolder() {
  base="$1"
  label="$2"
  PICKED=""

  : > "$TMP" || true
  rclone lsf "$base" --dirs-only --max-depth 1 2>/dev/null | sed 's:/$::' > "$TMP" || true

  if [ ! -s "$TMP" ]; then
    say
    say "No subfolders found under ${label}/"
    return 1
  fi

  say
  say "Subfolders under ${label}/:"
  say "----------------------------"
  nl -w2 -s') ' "$TMP"
  say

  while :; do
    printf "Choose a NUMBER (or 'q' to quit): "
    read -r ans

    case "$ans" in
      q|Q) return 1 ;;
    esac

    case "$ans" in
      *[!0-9]*|'') say "Please enter a number."; continue ;;
    esac

    sel="$(sed -n "${ans}p" "$TMP" | tr -d '\r')"
    if [ -z "${sel:-}" ]; then
      say "Invalid selection."
      continue
    fi

    PICKED="$sel"
    return 0
  done
}

main_menu() {
  while :; do
    say
    say "=== B2 LIST MENU (${BUCKET_NAME}) ==="
    say "1) root (shows: current/ Archive/ deleted/)"
    say "2) current (list root files + subfolders + size)"
    say "3) Archive (pick a subfolder, then list it)"
    say "4) deleted (pick a date folder, then list it)"
    say "q) quit"
    say
    printf "Select: "
    read -r choice

    case "$choice" in
      1) list_root_prefixes ;;
      2) list_path_depth1 "$CUR" "current" ;;
      3)
        if pick_subfolder "$ARC" "Archive"; then
          list_path_depth1 "$ARC/$PICKED" "Archive/$PICKED"
        fi
        ;;
      4)
        if pick_subfolder "$DEL" "deleted"; then
          list_path_depth1 "$DEL/$PICKED" "deleted/$PICKED"
        fi
        ;;
      q|Q) exit 0 ;;
      *) say "Invalid selection." ;;
    esac
  done
}

main_menu
