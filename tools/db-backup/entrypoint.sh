#!/bin/sh
# Initializes cron for database backups and keeps the container alive.
set -eu

install_packages() {
  if command -v microdnf >/dev/null 2>&1; then
    microdnf install -y cronie tzdata >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y cronie tzdata >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    yum install -y cronie tzdata >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cron tzdata >/dev/null
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache mysql-client tzdata >/dev/null
  else
    echo "No supported package manager found to install cron/tzdata" >&2
    exit 1
  fi
}

setup_cron() {
  : "${DB_BACKUP_SCHEDULE:=0 4 * * *}"
  mkdir -p /etc/cron.d
  echo "${DB_BACKUP_SCHEDULE} root /opt/db-backup/db-backup.sh >> /proc/1/fd/1 2>&1" > /etc/cron.d/db-backup
  chmod 0644 /etc/cron.d/db-backup
}

run_initial_backup() {
  if [ "${DB_BACKUP_RUN_ON_START:-true}" = "true" ]; then
    /opt/db-backup/db-backup.sh
  fi
}

install_packages
setup_cron
run_initial_backup

if command -v cron >/dev/null 2>&1; then
  exec cron -f
elif command -v crond >/dev/null 2>&1; then
  exec crond -n -s
else
  echo "cron daemon not found (cron/crond missing)" >&2
  exit 1
fi

