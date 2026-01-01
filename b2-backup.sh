#!/bin/sh
# TrueNAS / FreeBSD rclone B2 backup with lock + daily logs.
# Works for both cron and manual runs.

set -eu

LOCKFILE="/var/run/rclone-b2.lock"
SRC="/data"
BUCKET="backblaze:truenas-backup-mdemeczky"
DST="${BUCKET}/current"
DATE="$(date +%F)"
LOGFILE="/var/log/rclone-b2-${DATE}.log"

# Defaults
TRANSFERS="${TRANSFERS:-4}"
CHECKERS="${CHECKERS:-8}"
PROGRESS=0
DRYRUN=0

usage() {
  cat <<EOF
Usage: $0 [--progress] [--dry-run]

Options:
  --progress   Show progress (useful for manual runs)
  --dry-run    Do not make changes, just show what would happen

Env overrides:
  SRC=/data
  BUCKET=backblaze:truenas-backup-mdemeczky
  TRANSFERS=4
  CHECKERS=8
EOF
}

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --progress) PROGRESS=1 ;;
    --dry-run)  DRYRUN=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

# Build rclone args
RCLONE_ARGS=""
RCLONE_ARGS="$RCLONE_ARGS --backup-dir ${BUCKET}/deleted/${DATE}"
RCLONE_ARGS="$RCLONE_ARGS --transfers ${TRANSFERS}"
RCLONE_ARGS="$RCLONE_ARGS --checkers ${CHECKERS}"
RCLONE_ARGS="$RCLONE_ARGS --log-file ${LOGFILE}"
RCLONE_ARGS="$RCLONE_ARGS --log-level INFO"

if [ "$PROGRESS" -eq 1 ]; then
  RCLONE_ARGS="$RCLONE_ARGS --progress"
fi

if [ "$DRYRUN" -eq 1 ]; then
  RCLONE_ARGS="$RCLONE_ARGS --dry-run"
fi

# Run under lock (FreeBSD lockf)
# If already running, lockf exits non-zero immediately because of -t 0.
lockf -t 0 "$LOCKFILE" sh -c "
  echo \"[$(date -Is)] Starting rclone sync: ${SRC} -> ${DST}\" >> \"${LOGFILE}\"
  rclone sync \"${SRC}\" \"${DST}\" ${RCLONE_ARGS}
  rc=\$?
  echo \"[$(date -Is)] Finished rclone sync with exit code: \$rc\" >> \"${LOGFILE}\"
  exit \$rc
"

