#!/usr/bin/env bash
set -euo pipefail

# CONFIG: adjust if your compose service names or DB creds differ
WS_SVC="ac-worldserver"
DB_HOST="ac-database"
DB_USER="root"
DB_PASS="${MYSQL_ROOT_PASSWORD:-password}"   # falls back to 'password'
AUTH_DB="acore_auth"
WORLD_DB="acore_world"
CHAR_DB="acore_characters"

echo "=== Module SQL Import (v2) ==="
echo "WS: $WS_SVC  DB: $DB_HOST  USER: $DB_USER"

# Helper to run a command in the worldserver container
xin() { docker compose exec -T "$WS_SVC" bash -lc "$*"; }

# Import every .sql in a container path into a given DB
import_dir() {
  local db="$1"
  local dir="$2"
  local label="$3"

  # Skip if dir missing
  if ! xin "[ -d '$dir' ]"; then
    echo "  - ($label) skip, not found: $dir"
    return 0
  fi

  # Find *.sql recursively, sort by path to ensure base then updates order
  echo "  - ($label) scanning $dir ..."
  local cmd="
    shopt -s nullglob
    mapfile -t files < <(find '$dir' -type f -name '*.sql' | sort)
    for f in \"\${files[@]}\"; do
      echo \"    importing: \$f\"
      mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $db < \"\$f\"
    done
  "
  xin "$cmd"
}

echo
echo ">>> Importing module SQL (auth/world/characters) if present..."

########################
# mod-ah-bot (WORLD)
# Known layouts:
#   modules/mod-ah-bot/data/sql/...
########################
import_dir "$WORLD_DB" "/azerothcore/modules/mod-ah-bot/data/sql/base"        "ah-bot base"
import_dir "$WORLD_DB" "/azerothcore/modules/mod-ah-bot/data/sql/world"       "ah-bot world"
import_dir "$WORLD_DB" "/azerothcore/modules/mod-ah-bot/data/sql/updates"     "ah-bot updates"
# Some forks use a single dir:
import_dir "$WORLD_DB" "/azerothcore/modules/mod-ah-bot/data/sql"             "ah-bot root-sql"

########################
# mod-transmog (AUTH/WORLD/CHARACTERS)
# Common layouts use db-<dbname> folders
########################
for seg in auth world characters; do
  case "$seg" in
    auth)  db="$AUTH_DB" ;;
    world) db="$WORLD_DB" ;;
    characters) db="$CHAR_DB" ;;
  esac
  import_dir "$db" "/azerothcore/modules/mod-transmog/data/sql/db-$seg" "transmog db-$seg"
done
# older/alt layout fallback:
import_dir "$WORLD_DB" "/azerothcore/modules/mod-transmog/data/sql/world"     "transmog world (legacy)"
import_dir "$AUTH_DB"  "/azerothcore/modules/mod-transmog/data/sql/auth"      "transmog auth (legacy)"
import_dir "$CHAR_DB"  "/azerothcore/modules/mod-transmog/data/sql/characters" "transmog characters (legacy)"

########################
# mod-reward-played-time (WORLD/CHARACTERS)
########################
import_dir "$WORLD_DB" "/azerothcore/modules/mod-reward-played-time/data/sql/world"       "reward-time world"
import_dir "$CHAR_DB"  "/azerothcore/modules/mod-reward-played-time/data/sql/characters"  "reward-time characters"
# fallback:
import_dir "$WORLD_DB" "/azerothcore/modules/mod-reward-played-time/data/sql/db-world"    "reward-time db-world"
import_dir "$CHAR_DB"  "/azerothcore/modules/mod-reward-played-time/data/sql/db-characters" "reward-time db-characters"

########################
# mod-account-achievements (CHARACTERS)
########################
import_dir "$CHAR_DB" "/azerothcore/modules/mod-account-achievements/data/sql/characters"  "acc-achievements chars"
import_dir "$CHAR_DB" "/azerothcore/modules/mod-account-achievements/data/sql/db-characters" "acc-achievements db-chars"

########################
# mod-account-mounts (CHARACTERS)
########################
import_dir "$CHAR_DB" "/azerothcore/modules/mod-account-mounts/data/sql/characters"       "acc-mounts chars"
import_dir "$CHAR_DB" "/azerothcore/modules/mod-account-mounts/data/sql/db-characters"    "acc-mounts db-chars"

########################
# mod-aoe-loot (usually no SQL; keep for future)
########################
import_dir "$WORLD_DB" "/azerothcore/modules/mod-aoe-loot/data/sql/world"     "aoe-loot world"
import_dir "$WORLD_DB" "/azerothcore/modules/mod-aoe-loot/data/sql/db-world"  "aoe-loot db-world"

########################
# mod-solo-lfg (usually no SQL; keep for future)
########################
import_dir "$WORLD_DB" "/azerothcore/modules/mod-solo-lfg/data/sql/world"     "solo-lfg world"
import_dir "$WORLD_DB" "/azerothcore/modules/mod-solo-lfg/data/sql/db-world"  "solo-lfg db-world"

echo
echo ">>> Post-checks for critical tables..."

# AHBot table (WORLD)
xin "mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -N -e \"SHOW TABLES LIKE 'mod_auctionhousebot';\" $WORLD_DB" || true

# Transmog appearances (CHARACTERS)
xin "mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -N -e \"SHOW TABLES LIKE 'custom_unlocked_appearances';\" $CHAR_DB" || true

echo "=== Import complete ==="
