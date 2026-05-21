#!/usr/bin/env bash
# Sync local working tree to remote server `zzz` and (re)start the app.
#
# Usage:
#   ./sync.sh                rsync + docker compose up -d
#   ./sync.sh --rebuild      rsync + docker compose build + up -d
#                            use after any Python / web source change; -b is short form
#   ./sync.sh --dry-run      preview only
#   ./sync.sh --no-restart   rsync only, skip docker compose (incompatible with --rebuild)
#   ./sync.sh --delete       also delete remote files missing locally
set -euo pipefail

SERVER="zzz"
REMOTE_PATH="/home/think-chatgpt2api"
COMPOSE_FILE="docker-compose.prod.yml"
LOCAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXCLUDES=(
  --exclude='.git/'
  --exclude='data/'
  --exclude='logs/'
  --exclude='node_modules/'
  --exclude='.DS_Store'
  --exclude='*.swp'
  --exclude='*.tmp'
  --exclude='web/*/dist/'
  --exclude='web/*/build/'
  --exclude='.env'
  --exclude='.env.local'
  --exclude='*.db'
  --exclude='*.sqlite'
  --exclude='git_cache/'
  --exclude='.venv/'
  --exclude='__pycache__/'
)

DRY=""
DELETE=""
NO_RESTART=""
REBUILD=""
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY="--dry-run" ;;
    --delete)     DELETE="--delete" ;;
    --no-restart) NO_RESTART=1 ;;
    --rebuild|-b) REBUILD=1 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

if [[ -n "$REBUILD" && -n "$NO_RESTART" ]]; then
  echo "Error: --rebuild and --no-restart are mutually exclusive" >&2
  exit 2
fi

echo "==> rsync $LOCAL_PATH/ -> $SERVER:$REMOTE_PATH/ (compose: $COMPOSE_FILE)"
rsync -avzh --progress \
  $DRY $DELETE \
  "${EXCLUDES[@]}" \
  "$LOCAL_PATH/" "$SERVER:$REMOTE_PATH/"

if [[ -n "$DRY" ]]; then
  echo "==> dry-run, skipping docker compose"
  exit 0
fi
if [[ -n "$NO_RESTART" ]]; then
  echo "==> --no-restart, skipping docker compose"
  exit 0
fi

if [[ -n "$REBUILD" ]]; then
  echo "==> docker compose -f $COMPOSE_FILE build  (~3-5min cold)"
  ssh "$SERVER" "cd $REMOTE_PATH && docker compose -f $COMPOSE_FILE build"
fi

echo "==> docker compose -f $COMPOSE_FILE up -d"
ssh "$SERVER" "cd $REMOTE_PATH && docker compose -f $COMPOSE_FILE up -d"

echo "==> done"
