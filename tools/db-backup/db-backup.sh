#!/bin/sh
# Simple MySQL backup helper used by the ac-db-backup container.
set -eu

umask 077

BACKUP_DIR="${DB_BACKUP_DIR:-/backups}"
DB_HOST="${DB_BACKUP_HOST:-ac-database}"
DB_PORT="${DB_BACKUP_PORT:-3306}"
DB_USER="${DB_BACKUP_USER:-root}"
DB_PASSWORD="${DB_BACKUP_PASSWORD:-password}"
DB_NAMES="${DB_BACKUP_DATABASES:-acore_auth acore_characters acore_world acore_playerbots}"
RETENTION_DAYS="${DB_BACKUP_RETENTION_DAYS:-7}"
EXTRA_OPTS="${DB_BACKUP_EXTRA_OPTS:---single-transaction --routines --events --triggers --quick}"

timestamp="$(date "+%Y%m%d-%H%M%S")"
mkdir -p "${BACKUP_DIR}"

log() {
  printf "[%s] %s\n" "$(date "+%Y-%m-%dT%H:%M:%S%z")" "$*"
}

for db in ${DB_NAMES}; do
  tmp_path="${BACKUP_DIR}/${db}_${timestamp}.sql"
  archive_path="${tmp_path}.gz"

  log "Starting dump for database '${db}'"
  if mysqldump \
      -h "${DB_HOST}" \
      -P "${DB_PORT}" \
      -u "${DB_USER}" \
      -p"${DB_PASSWORD}" \
      ${EXTRA_OPTS} \
      "${db}" > "${tmp_path}"
  then
    gzip -9 "${tmp_path}"
    log "Backup written to ${archive_path}"
  else
    log "Backup FAILED for '${db}'" >&2
    rm -f "${tmp_path}"
    exit 1
  fi
done

if [ "${RETENTION_DAYS}" -gt 0 ] 2>/dev/null; then
  log "Pruning backups older than ${RETENTION_DAYS} days"
  find "${BACKUP_DIR}" -type f -name "*.sql.gz" -mtime +"${RETENTION_DAYS}" -print -delete
fi

log "Backup run complete"

