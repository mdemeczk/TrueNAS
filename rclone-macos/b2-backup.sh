#!/bin/sh
# TrueNAS / FreeBSD rclone B2 backup with lock + daily logs.
# Cron + manual safe (single instance via lockf).

set -eu

LOCKFILE="/var/run/rclone-b2.lock"
SRC="${SRC:-/data}"
BUCKET="${BUCKET:-rclone-macos:truenas-backup-mdemeczky}"
DST="${BUCKET}/current"

DATE="$(date +"%Y-%m-%d")"
NOW() { date +"%Y-%m-%d %H:%M:%S"; }

LOGFILE="/var/log/rclone-b2-${DATE}.log"

TRANSFERS="${TRANSFERS:-4}"
CHECKERS="${CHECKERS:-8}"
PROGRESS=0
DRYRUN=0

usage() {
  cat <<EOF
Usage: $0 [--progress] [--dry-run]

Options:
  --progress   Show progress (manual runs)
  --dry-run    No changes, show actions only

Env overrides:
  SRC=/data
  BUCKET=rclone-macos:truenas-backup-mdemeczky
  TRANSFERS=4
  CHECKERS=8
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --progress) PROGRESS=1 ;;
    --dry-run)  DRYRUN=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

mkdir -p /var/log 2>/dev/null || true
mkdir -p /var/run 2>/dev/null || true

# Build rclone args (as positional args, not a single string)
set -- \
  "--backup-dir" "${BUCKET}/deleted/${DATE}" \
  "--transfers" "${TRANSFERS}" \
  "--checkers" "${CHECKERS}" \
  "--log-file" "${LOGFILE}" \
  "--log-level" "INFO"

if [ "$PROGRESS" -eq 1 ]; then
  set -- "$@" "--progress"
fi

if [ "$DRYRUN" -eq 1 ]; then
  set -- "$@" "--dry-run"
fi

# If already running, exit cleanly and log it.
if ! lockf -t 0 "$LOCKFILE" true 2>/dev/null; then
  echo "[$(NOW)] Another backup is already running. Exiting." >> "$LOGFILE"
  exit 0
fi

# Run under the lock (this keeps the lock for the whole command)
lockf -t 0 "$LOCKFILE" sh -c '
  echo "['"$(NOW)"'] Starting rclone sync: '"$SRC"' -> '"$DST"'" >> "'"$LOGFILE"'"
  rclone sync "'"$SRC"'" "'"$DST"'" "$@"
  rc=$?
  echo "['"$(NOW)"'] Finished rclone sync with exit code: $rc" >> "'"$LOGFILE"'"
  exit $rc
' sh "$@"

