#!/usr/bin/env bash

set -euo pipefail

run_tools() {
  docker compose --profile tools run --rm "$@" 2> >(grep -v "No services to build" >&2)
}

COMPOSE_DIR="/mnt/d/[ Infra ]/docker/immich"
BASE_WIN_BACKUP_ROOT="/mnt/d/[ Infra ]/docker/immich/backups"

cd "$COMPOSE_DIR"

TS="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="${BASE_WIN_BACKUP_ROOT}/${TS}"

mkdir -p "$BACKUP_DIR"
echo "==> Backup dir: $BACKUP_DIR"

# Export BACKUP_DIR so docker compose can substitute ${BACKUP_DIR}
export BACKUP_DIR

echo "==> Stopping DB (recommended for raw pgdata copy consistency)..."
docker compose stop immich-db || true

echo "==> Exporting raw pgdata to $BACKUP_DIR/pgdata ..."
run_tools pgdata_export

echo "==> Starting DB..."
docker compose start immich-db

echo "==> Writing SQL dump into $BACKUP_DIR ..."
run_tools pg_dump

echo "==> Done."
