#!/usr/bin/env bash
set -euo pipefail

# Host-side paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_MODULES_DIR="$REPO_ROOT/modules"
HOST_CONF_DIR="$REPO_ROOT/conf/modules"

# Container service/name + container conf dir
WS_SVC="ac-worldserver"
CTR_CONF_DIR="/azerothcore/env/dist/etc/modules"

echo "=== Preparing module configs on host ==="
mkdir -p "$HOST_CONF_DIR"

# 1) Copy all module confs from host modules/**/conf/*.conf.dist -> conf/modules/*.conf
echo ">> Scanning host ./modules/**/conf/*.conf.dist ..."
shopt -s nullglob
found=0
while IFS= read -r -d '' dist; do
  found=1
  base="$(basename "$dist")"                  # e.g., mod_ahbot.conf.dist
  out="$HOST_CONF_DIR/${base%.conf.dist}.conf"
  if [[ -f "$out" ]]; then
    echo "   - exists: $(basename "$out")"
  else
    cp "$dist" "$out"
    echo "   + created: $(basename "$out")"
  fi
done < <(find "$HOST_MODULES_DIR" -type f -path "*/conf/*.conf.dist" -print0)
shopt -u nullglob
[[ $found -eq 1 ]] || echo "   (no module conf.dist files found under ./modules/**/conf/)"

# 2) Pull any extra *.conf.dist that only exist inside the container (fallbacks)
#    This covers cases where a module drops its template into the env dir at build-time.
echo ">> Checking container for extra *.conf.dist in $CTR_CONF_DIR ..."
# Get list of .conf.dist in container (if container is up)
if docker compose ps -q "$WS_SVC" >/dev/null 2>&1 && [[ -n "$(docker compose ps -q "$WS_SVC")" ]]; then
  mapfile -t ctr_dists < <(docker compose exec -T "$WS_SVC" bash -lc "shopt -s nullglob; for f in $CTR_CONF_DIR/*.conf.dist; do echo \"\$f\"; done" || true)
  if (( ${#ctr_dists[@]} )); then
    for f in "${ctr_dists[@]}"; do
      name="$(basename "$f")"                    # e.g., playerbots.conf.dist
      out="$HOST_CONF_DIR/${name%.conf.dist}.conf"
      if [[ -f "$out" ]]; then
        echo "   - exists: $(basename "$out")"
      else
        # read file content from container and write to host
        docker compose exec -T "$WS_SVC" bash -lc "cat '$f'" > "$out"
        echo "   + pulled from container: $(basename "$out")"
      fi
    done
  else
    echo "   (none found in container; it may not place templates there)"
  fi
else
  echo "   (worldserver container not running; skip container fallbacks)"
fi

echo
echo "=== Host module configs now present in ./conf/modules ==="
ls -1 "$HOST_CONF_DIR" || true
echo "=== Done ==="

