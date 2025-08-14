#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/_lib.sh"; need_root

# stop services
systemctl stop gitlab-runner || true
systemctl stop runner-admin || true
systemctl disable runner-admin || true

# remove runner
apt-get -y purge gitlab-runner
rm -rf /etc/gitlab-runner /var/lib/gitlab-runner

# remove admin server (if present)
rm -f /etc/systemd/system/runner-admin.service
rm -f /etc/sudoers.d/runner-admin
rm -rf /opt/debian-secure-gitlab-runner

log "GitLab Runner and optional admin UI removed."
