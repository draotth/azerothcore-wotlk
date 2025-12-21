#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="${1:-/storage/downloads/wowdata}"
DEST_DIR="${CLIENT_DATA_DIR:-/storage/dockerVolumes/wow-data}"
REQUIRED_SUBDIRS=(dbc maps mmaps vmaps)
# directories/binaries to skip while syncing (bin contains server executables)
EXCLUDE_ITEMS=(data-version authserver worldserver)

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "Source directory '${SRC_DIR}' does not exist." >&2
    exit 1
fi

missing=()
for dir in "${REQUIRED_SUBDIRS[@]}"; do
    [[ -d "${SRC_DIR}/${dir}" ]] || missing+=("${dir}")
done

if (( ${#missing[@]} )); then
    echo "Source is missing required sub-directories: ${missing[*]}" >&2
    exit 1
fi

echo "Inspecting source folder structure in '${SRC_DIR}'..."
src_dirs=$(find "${SRC_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
printf '%s\n' "${src_dirs}" | sed 's/^/  - /'

echo
echo "Ensuring destination directory '${DEST_DIR}' exists..."
mkdir -p "${DEST_DIR}"

echo "Inspecting destination directory '${DEST_DIR}'..."
dest_dirs=$(find "${DEST_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort 2>/dev/null || true)

if [[ -n "${dest_dirs}" ]]; then
    printf '%s\n' "${dest_dirs}" | sed 's/^/  - /'
else
    echo "  (no directories present yet)"
fi

echo
tmp_src=$(mktemp)
tmp_dst=$(mktemp)
printf '%s\n' "${src_dirs}" > "${tmp_src}"
printf '%s\n' "${dest_dirs}" > "${tmp_dst}"
echo "Directory delta (destination vs source):"
if ! comm -3 "${tmp_dst}" "${tmp_src}"; then
    true
fi
rm -f "${tmp_src}" "${tmp_dst}"

read -r -p "Proceed with rsync from '${SRC_DIR}' to directory '${DEST_DIR}'? [y/N] " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Synchronizing client data..."

rsync_cmd=(rsync -av --delete)
for item in "${EXCLUDE_ITEMS[@]}"; do
    rsync_cmd+=("--exclude" "${item}")
done
rsync_cmd+=("${SRC_DIR}/" "${DEST_DIR}/")

"${rsync_cmd[@]}"

echo "Sync complete."

