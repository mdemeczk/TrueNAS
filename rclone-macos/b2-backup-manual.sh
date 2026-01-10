BUCKET="backblaze:truenas-backup-mdemeczky"
rclone sync /data "${BUCKET}/current" \
  --backup-dir "${BUCKET}/deleted/$(date +%F)" \
  --progress \
  --transfers 4 \
  --checkers 8 \
  --log-file="/var/log/rclone-b2-manual-$(date +%F-%H%M).log"

