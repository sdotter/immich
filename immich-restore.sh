#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# Configuration
# -----------------------
COMPOSE_DIR="/mnt/d/[ Infra ]/docker/immich"
BACKUP_ROOT="${COMPOSE_DIR}/backups"
DB_SERVICE="immich-db"
RESTORE_SERVICE="pg_restore"   # compose tool service name

# -----------------------
# Helpers
# -----------------------
die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

compose_tools() {
  docker compose --profile tools run --rm "$@" \
    2> >(grep -v '^WARN\[.*\] No services to build$' >&2)
}

get_env_value() {
  local key="$1"
  grep -E "^${key}=" .env | head -n1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

# -----------------------
# Main
# -----------------------
cd "$COMPOSE_DIR"

TS="${1:-}"
[ -n "$TS" ] || {
  echo "Usage: $0 <timestamp-folder>"
  echo "Example: $0 20260105180930"
  echo
  echo "Available backups:"
  ls -1 "$BACKUP_ROOT" 2>/dev/null || true
  exit 1
}

BACKUP_DIR="${BACKUP_ROOT}/${TS}"
SQL_FILE="$(ls -1t "${BACKUP_DIR}"/immich-db_*.sql 2>/dev/null | head -n 1 || true)"

[ -d "$BACKUP_DIR" ] || die "Backup folder not found: $BACKUP_DIR"
[ -n "$SQL_FILE" ]   || die "No immich-db_*.sql found in $BACKUP_DIR"

# Exports for compose substitutions
export BACKUP_DIR
export RESTORE_FILE="$SQL_FILE"

# Optional wipe info
DB_DATA_LOCATION="$(get_env_value DB_DATA_LOCATION || true)"

info "Backup dir: $BACKUP_DIR"
info "SQL file:   $RESTORE_FILE"
echo

read -r -p "Wipe database files before restore? (y/N): " WIPE_ANSWER
WIPE_ANSWER="${WIPE_ANSWER:-N}"

echo
echo "This will restore from the SQL dump."
[ "${WIPE_ANSWER}" = "y" ] || [ "${WIPE_ANSWER}" = "Y" ] && {
  echo "Additionally it will DELETE ALL files inside: ${DB_DATA_LOCATION:-<unknown DB_DATA_LOCATION>}"
}
echo
read -r -p "Type RESTORE to continue: " CONFIRM
[ "$CONFIRM" = "RESTORE" ] || die "Aborted."

# If user chose wipe, do it
if [ "${WIPE_ANSWER}" = "y" ] || [ "${WIPE_ANSWER}" = "Y" ]; then
  [ -n "${DB_DATA_LOCATION:-}" ] || die "DB_DATA_LOCATION not found in .env (cannot wipe safely)"

  case "$DB_DATA_LOCATION" in
    ""|"/") die "Refusing to wipe empty path or /" ;;
  esac

  info "Stopping DB..."
  docker compose stop "$DB_SERVICE" || true

  info "Wiping database directory contents..."
  sudo mkdir -p "$DB_DATA_LOCATION"
  sudo rm -rf "${DB_DATA_LOCATION:?}/"*

  info "Starting DB (fresh init)..."
  docker compose start "$DB_SERVICE"

  info "Waiting for DB..."
  sleep 5
else
  # No wipe: just ensure DB is running
  info "Starting DB..."
  docker compose start "$DB_SERVICE"
  info "Waiting for DB..."
  sleep 3
fi

info "Restoring SQL into database..."
compose_tools "$RESTORE_SERVICE"

info "Done."