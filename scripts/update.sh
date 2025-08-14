#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/_lib.sh"; need_root
apt-get update -y && apt-get install -y gitlab-runner
systemctl restart gitlab-runner
gitlab-runner --version
log "Updated."
