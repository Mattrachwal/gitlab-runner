#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(dirname "$0")/.."
ACTION="${1:-}"

case "$ACTION" in
  set-concurrent)
    exec "$REPO_ROOT/scripts/set-concurrent.sh"
    ;;
  register)
    exec "$REPO_ROOT/scripts/register-from-json.sh"
    ;;
  restart)
    systemctl restart gitlab-runner
    echo "restarted"
    ;;
  list)
    sudo -u gitlab-runner gitlab-runner list
    ;;
  *)
    echo "unknown action" >&2
    exit 2
    ;;
esac
