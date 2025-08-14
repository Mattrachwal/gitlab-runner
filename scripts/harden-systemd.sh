#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/_lib.sh"
need_root

mkdir -p /etc/systemd/system/gitlab-runner.service.d
cp "$(dirname "$0")/../config/systemd-dropin-override.conf" /etc/systemd/system/gitlab-runner.service.d/override.conf

systemctl daemon-reload
systemctl restart gitlab-runner
systemctl --no-pager status gitlab-runner || true
log "Systemd hardening applied."
