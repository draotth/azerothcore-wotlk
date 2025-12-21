#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Wipes every Playerbot the same way the upstream mod-playerbots wiki suggests.
# Reference: https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Queries

MYSQL_BIN="${MYSQL_BIN:-mysql}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-password}"
AUTH_DB="${AUTH_DB:-acore_auth}"
CHAR_DB="${CHAR_DB:-acore_characters}"
PLAYERBOTS_DB="${PLAYERBOTS_DB:-acore_playerbots}"
WORLD_DB="${WORLD_DB:-acore_world}"
ASSUME_YES=0
MYSQL_CMD=("$MYSQL_BIN")
DOCKER_COMPOSE_CMD=()

init_docker_compose() {
    if [[ ${#DOCKER_COMPOSE_CMD[@]} -gt 0 ]]; then
        return 0
    fi

    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD=(docker compose)
        return 0
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD=(docker-compose)
        return 0
    fi

    return 1
}

ensure_mysql_client() {
    if command -v "${MYSQL_CMD[0]}" >/dev/null 2>&1; then
        return 0
    fi

    if init_docker_compose; then
        MYSQL_CMD=("${DOCKER_COMPOSE_CMD[@]}" exec -T ac-database mysql)
        return 0
    fi

    echo "mysql client not found (override with MYSQL_BIN)" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $0 [options]

Executes the Playerbot cleanup queries documented by mod-playerbots.

Options:
  -H, --host HOST        Database host (default: $DB_HOST)
  -P, --port PORT        Database port (default: $DB_PORT)
  -u, --user USER        Database user (default: $DB_USER)
  -p, --password PASS    Database password (default: $DB_PASS)
  --auth-db NAME         Auth database name (default: $AUTH_DB)
  --char-db NAME         Characters database name (default: $CHAR_DB)
  --playerbots-db NAME   Playerbots database name (default: $PLAYERBOTS_DB)
  --world-db NAME        World database name (default: $WORLD_DB)
  -y, --yes              Skip interactive confirmation
  -h, --help             Show this message

Environment overrides:
  MYSQL_BIN, DB_HOST, DB_PORT, DB_USER, DB_PASS,
  AUTH_DB, CHAR_DB, PLAYERBOTS_DB, WORLD_DB
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -H|--host) DB_HOST="$2"; shift 2 ;;
        -P|--port) DB_PORT="$2"; shift 2 ;;
        -u|--user) DB_USER="$2"; shift 2 ;;
        -p|--password) DB_PASS="$2"; shift 2 ;;
        --auth-db) AUTH_DB="$2"; shift 2 ;;
        --char-db) CHAR_DB="$2"; shift 2 ;;
        --playerbots-db) PLAYERBOTS_DB="$2"; shift 2 ;;
        --world-db) WORLD_DB="$2"; shift 2 ;;
        -y|--yes) ASSUME_YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

ensure_mysql_client

MYSQL_ARGS=(-h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER")
if [[ -n "${DB_PASS:-}" ]]; then
    MYSQL_ARGS+=(-p"$DB_PASS")
fi

run_sql() {
    local db="$1"
    local sql="$2"

    printf "\n>>> Cleaning %s ...\n" "$db"
    if ! printf '%s\n' "$sql" | "${MYSQL_CMD[@]}" "${MYSQL_ARGS[@]}" "$db"; then
        echo "Failed running cleanup statements against $db" >&2
        exit 1
    fi
}

mysql_query() {
    local db="$1"
    local sql="$2"
    "${MYSQL_CMD[@]}" "${MYSQL_ARGS[@]}" -N -B "$db" -e "$sql"
}

sql_escape() {
    local input="${1//\'/\'\'}"
    printf "%s" "$input"
}

if [[ $ASSUME_YES -eq 0 ]]; then
    cat <<CONFIRM
This will irreversibly delete:
  * All random Playerbots (DB: $PLAYERBOTS_DB)
  * Any characters created for RNDBOT accounts (DB: $CHAR_DB)
  * Any RNDBOT accounts plus auth/realm records without characters (DB: $AUTH_DB)
  * Associated guild/group/mail data for deleted characters
CONFIRM
    read -r -p "Proceed? [y/N] " answer
    case "$answer" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
fi

PLAYERBOTS_SQL=$(cat <<SQL
DELETE FROM \`playerbots_random_bots\`;
DELETE FROM \`playerbots_account_type\`;
SQL
)

CHARACTERS_SQL=$(cat <<SQL
DELETE FROM \`characters\` WHERE \`account\` IN (SELECT \`id\` FROM \`${AUTH_DB}\`.\`account\` WHERE \`username\` LIKE 'RNDBOT%') OR \`account\` NOT IN (SELECT \`id\` FROM \`${AUTH_DB}\`.\`account\`);
DELETE FROM \`arena_team_member\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`arena_team\` WHERE \`arenaTeamId\` NOT IN (SELECT \`arenaTeamId\` FROM \`arena_team_member\`);
DELETE FROM \`character_account_data\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_achievement\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_achievement_progress\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_action\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_aura\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_glyphs\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_homebind\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`item_instance\` WHERE \`owner_guid\` NOT IN (SELECT \`guid\` FROM \`characters\`) AND \`owner_guid\` > 0;
DELETE FROM \`character_inventory\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_pet\` WHERE \`owner\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`pet_aura\` WHERE \`guid\` NOT IN (SELECT \`id\` FROM \`character_pet\`);
DELETE FROM \`pet_spell\` WHERE \`guid\` NOT IN (SELECT \`id\` FROM \`character_pet\`);
DELETE FROM \`pet_spell_cooldown\` WHERE \`guid\` NOT IN (SELECT \`id\` FROM \`character_pet\`);
DELETE FROM \`character_queststatus\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_queststatus_rewarded\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_reputation\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_skills\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_social\` WHERE \`friend\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_spell\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_spell_cooldown\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_talent\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`corpse\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`groups\` WHERE \`leaderGuid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`group_member\` WHERE \`memberGuid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`mail\` WHERE \`receiver\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`mail_items\` WHERE \`receiver\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`guild\` WHERE \`leaderguid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`guild_bank_eventlog\` WHERE \`guildid\` NOT IN (SELECT \`guildid\` FROM \`guild\`);
DELETE FROM \`guild_member\` WHERE \`guildid\` NOT IN (SELECT \`guildid\` FROM \`guild\`) OR \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`guild_rank\` WHERE \`guildid\` NOT IN (SELECT \`guildid\` FROM \`guild\`);
DELETE FROM \`petition\` WHERE \`ownerguid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`petition_sign\` WHERE \`ownerguid\` NOT IN (SELECT \`guid\` FROM \`characters\`) OR \`playerguid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_arena_stats\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
DELETE FROM \`character_entry_point\` WHERE \`guid\` NOT IN (SELECT \`guid\` FROM \`characters\`);
SQL
)

AUTH_SQL=$(cat <<SQL
DELETE FROM \`account\` WHERE \`username\` LIKE 'RNDBOT%';
DELETE FROM \`realmcharacters\` WHERE \`acctid\` NOT IN (SELECT \`id\` FROM \`account\`);
SQL
)

run_sql "$PLAYERBOTS_DB" "$PLAYERBOTS_SQL"
run_sql "$CHAR_DB" "$CHARACTERS_SQL"
run_sql "$AUTH_DB" "$AUTH_SQL"

echo
echo "Playerbots, RNDBOT characters, and associated auth data cleared successfully."
