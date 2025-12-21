#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Load root-level .env (if present) so DOCKER_* overrides are available.
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.env"
  set +a
fi

DEFAULT_ADDRESS="${REALMLIST_ADDRESS:-${SERVER_PUBLIC_IP:-10.9.29.4}}"
DEFAULT_PORT="${REALMLIST_PORT:-${DOCKER_WORLD_EXTERNAL_PORT:-10903}}"
DEFAULT_REALM_ID="${REALMLIST_ID:-0}"
AUTH_DB="${AUTH_DB:-acore_auth}"
DB_PASS="${DOCKER_DB_ROOT_PASSWORD:-password}"
ASSUME_YES=0

ADDRESS="$DEFAULT_ADDRESS"
PORT="$DEFAULT_PORT"
REALM_ID="$DEFAULT_REALM_ID"

usage() {
  cat <<EOF
Usage: $0 [options]

Sets the public address/port for every row in ${AUTH_DB}.realmlist.

Options:
  -a, --address IP_OR_HOST   Realm address (default: $DEFAULT_ADDRESS)
  -p, --port PORT            Realm port (default: $DEFAULT_PORT)
  -r, --realm-id ID          Realm ID to update (default: $DEFAULT_REALM_ID, 0 = all rows)
  -y, --yes                  Skip confirmation prompt
  -h, --help                 Show this help

Environment overrides:
  REALMLIST_ADDRESS, DOCKER_WORLD_EXTERNAL_PORT, REALMLIST_ID,
  AUTH_DB, DOCKER_DB_ROOT_PASSWORD, SERVER_PUBLIC_IP
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--address) ADDRESS="$2"; shift 2 ;;
    -p|--port) PORT="$2"; shift 2 ;;
    -r|--realm-id) REALM_ID="$2"; shift 2 ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$ADDRESS" ]]; then
  echo "Realm address cannot be empty" >&2
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Realm port must be a number (got: $PORT)" >&2
  exit 1
fi

if ! [[ "$REALM_ID" =~ ^[0-9]+$ ]]; then
  echo "Realm ID must be numeric (got: $REALM_ID)" >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "docker compose is not installed (need either 'docker compose' or 'docker-compose')" >&2
  exit 1
fi

if [[ -z "$("${COMPOSE_CMD[@]}" ps -q ac-database 2>/dev/null)" ]]; then
  echo "ac-database container is not running. Start it with: ${COMPOSE_CMD[*]} up -d ac-database" >&2
  exit 1
fi

mysql_exec() {
  local sql="$1"
  "${COMPOSE_CMD[@]}" exec -T ac-database \
    mysql -uroot "-p${DB_PASS}" -D "$AUTH_DB" \
    --protocol=TCP --silent --skip-column-names \
    -e "$sql"
}

mysql_exec_table() {
  local sql="$1"
  "${COMPOSE_CMD[@]}" exec -T ac-database \
    mysql -uroot "-p${DB_PASS}" -D "$AUTH_DB" \
    --protocol=TCP \
    -e "$sql"
}

escaped_address=${ADDRESS//\'/\'\'}
where_clause=""
if (( REALM_ID > 0 )); then
  where_clause="WHERE id = ${REALM_ID}"
fi

echo "=== Realm target ==="
echo " Address : $ADDRESS"
echo " Port    : $PORT"
if (( REALM_ID > 0 )); then
  echo " Realm ID: $REALM_ID"
else
  echo " Realm ID: all rows"
fi
echo

if [[ $ASSUME_YES -eq 0 ]]; then
  read -r -p "Proceed with updating realmlist? [y/N] " answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

echo ">>> Current realmlist rows"
mysql_exec_table "SELECT id,name,address,localAddress,port FROM realmlist ORDER BY id;"
echo

echo ">>> Applying UPDATE statement"
mysql_exec "UPDATE realmlist SET address='${escaped_address}', port=${PORT} ${where_clause};"
echo "Update complete."
echo

echo ">>> Updated realmlist rows"
mysql_exec_table "SELECT id,name,address,localAddress,port FROM realmlist ORDER BY id;"
echo "Done."

