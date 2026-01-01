#!/bin/sh

LOCKFILE="/var/run/rclone-b2.lock"
SRC="/data"
BUCKET="backblaze:truenas-backup-mdemeczky"
DST="${BUCKET}/current"
DATE=$(date +%F)
LOGFILE="/var/log/rclone-b2-${DATE}.log"

# --- lock (FreeBSD way) ---
lockf -t 0 "$LOCKFILE" sh -c '
  rclone sync "'"$SRC"'" "'"$DST"'" \
    --backup-dir "'"$BUCKET"'/deleted/'"$DATE"'" \
    --transfers 4 \
    --checkers 8 \
    --log-file "'"$LOGFILE"'" \
    --log-level INFO
'

