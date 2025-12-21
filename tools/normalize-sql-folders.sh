#!/usr/bin/env bash

# Normalizes module SQL folder names so the Playerbot fork's DB updater can find them.
# Usage: ./tools/normalize-sql-folders.sh [--dry-run]

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="$REPO_ROOT/modules"

if [[ ! -d "$MODULES_DIR" ]]; then
    echo "Modules directory not found at $MODULES_DIR" >&2
    exit 1
fi

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

schemas=(world auth characters)
normalized_dirs=0

for module_path in "$MODULES_DIR"/*; do
    [[ -d "$module_path" ]] || continue
    sql_root="$module_path/data/sql"
    [[ -d "$sql_root" ]] || continue

    for schema in "${schemas[@]}"; do
        legacy="$sql_root/db-$schema"
        target="$sql_root/$schema"

        if [[ -d "$legacy" ]]; then
            module_name="$(basename "$module_path")"
            echo "[$module_name] normalizing db-$schema -> $schema"

            if [[ $DRY_RUN -eq 0 ]]; then
                mkdir -p "$target"

                if compgen -A file "$legacy" >/dev/null; then
                    if ! cp -a "$legacy"/. "$target"/; then
                        echo "Failed to copy contents of $legacy to $target" >&2
                        continue
                    fi
                fi

                if ! rm -rf "$legacy"; then
                    echo "Failed to remove legacy folder $legacy" >&2
                    continue
                fi
            fi

            ((normalized_dirs++))
        fi
    done
done

if [[ $normalized_dirs -eq 0 ]]; then
    echo "No legacy db-* SQL folders were found."
else
    echo "Normalized $normalized_dirs legacy SQL folder(s)."
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "Dry-run mode: no files were modified."
    fi
fi

