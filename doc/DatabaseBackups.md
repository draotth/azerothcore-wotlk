# Database Backups

This project now ships a lightweight backup helper that runs as a Docker Compose service and writes compressed `mysqldump` archives to `var/backups/db`.

## Service

- Service name: `ac-db-backup` (now gated behind compose profile `backup`)
- Image: `mysql:8.4` (installs cron/tzdata at start via microdnf)
- Schedule: cron inside the container (default `0 4 * * *`)
- Output: gzip archives per database, e.g. `acore_world_20250101-040000.sql.gz`

## Enable / update

This service is disabled by default via a compose profile. Enable and start it explicitly:

```bash
docker compose --profile backup up -d ac-db-backup
# or bring everything up together
docker compose --profile backup up -d
```

Configuration lives in `docker-compose.override.yml`. The most relevant environment variables are:

- `DB_BACKUP_SCHEDULE` — cron expression, default `0 4 * * *`
- `DB_BACKUP_DATABASES` — space separated database names to dump
- `DB_BACKUP_RETENTION_DAYS` — prune files older than this value (default `7`)
- `DB_BACKUP_HOST` / `DB_BACKUP_PORT` / `DB_BACKUP_USER` / `DB_BACKUP_PASSWORD`
- `DB_BACKUP_DIR` — where dumps are written inside the container (default `/backups`, bound to `./var/backups/db`)
- `DB_BACKUP_RUN_ON_START` — `true` to run once at container start
- `DB_BACKUP_EXTRA_OPTS` — extra flags passed to `mysqldump` (default excludes GTID flags for MariaDB compatibility)

Changes to the schedule or credentials require a container restart: `docker compose restart ac-db-backup`.

## Restore (manual)

Pick a dump, then restore into the database container:

```bash
gunzip -c var/backups/db/acore_world_YYYYMMDD-HHMMSS.sql.gz | docker compose exec -T ac-database mysql -u root -p"$DOCKER_DB_ROOT_PASSWORD" acore_world
```

Replace `acore_world` with the database you need. The command runs inside the existing `ac-database` container so it inherits the same credentials and network.

