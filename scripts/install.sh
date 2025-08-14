#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/_lib.sh"
need_root

: "${SETUP_ADMIN_UI:=0}"             # 0 = off, 1 = install admin UI
: "${ADMIN_SUBNET:=192.168.1.0/24}"  # allowed LAN for UI
: "${ADMIN_PORT:=80}"                # UI port (default 80)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log "Base OS hygiene"
apt-get update -y
apt-get upgrade -y
apt-get install -y curl ca-certificates gnupg ufw apparmor apparmor-utils fail2ban unattended-upgrades jq git

log "Enable unattended-upgrades (noninteractive)"
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades || true

log "Add GitLab Runner apt repo"
curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash

log "Install gitlab-runner"
apt-get install -y gitlab-runner

# Directories with tight perms
BUILD_DIR="/var/lib/gitlab-runner/builds"
CACHE_DIR="/var/lib/gitlab-runner/cache"
install -d -o gitlab-runner -g gitlab-runner -m 0750 "$BUILD_DIR" "$CACHE_DIR"

# UFW baseline (SSH ok)
log "Configure UFW"
ufw allow OpenSSH || true
ufw --force enable

systemctl enable gitlab-runner
systemctl start gitlab-runner

if [[ "$SETUP_ADMIN_UI" == "1" ]]; then
  log "Setting up admin web UI (LAN ${ADMIN_SUBNET}, port ${ADMIN_PORT})"
  apt-get install -y nodejs npm

  # Create admin user & group
  addgroup --system runner-admin || true
  id -u runneradmin &>/dev/null || useradd -r -M -s /usr/sbin/nologin -g runner-admin runneradmin

  # Copy admin server
  install -d -m 0755 /opt/debian-secure-gitlab-runner
  rsync -a "$REPO_ROOT"/ /opt/debian-secure-gitlab-runner/
  chown -R root:root /opt/debian-secure-gitlab-runner

  # Root helper & sudoers
  chown root:root /opt/debian-secure-gitlab-runner/scripts/admin-ctl.sh
  chmod 0750 /opt/debian-secure-gitlab-runner/scripts/admin-ctl.sh
  cat >/etc/sudoers.d/runner-admin <<EOF
%runner-admin ALL=(root) NOPASSWD: /opt/debian-secure-gitlab-runner/scripts/admin-ctl.sh *
EOF
  chmod 0440 /etc/sudoers.d/runner-admin

  # Admin server deps
  pushd /opt/debian-secure-gitlab-runner/admin-server >/dev/null
  cp .env.example .env
  # set defaults: bind 0.0.0.0 and port
  sed -i "s|^HOST=.*|HOST=0.0.0.0|" .env
  sed -i "s|^PORT=.*|PORT=${ADMIN_PORT}|" .env
  npm install --omit=dev
  popd >/dev/null

  # Systemd unit
  cat >/etc/systemd/system/runner-admin.service <<'UNIT'
[Unit]
Description=GitLab Runner Local Admin
After=network.target

[Service]
User=runneradmin
Group=runner-admin
WorkingDirectory=/opt/debian-secure-gitlab-runner/admin-server
EnvironmentFile=/opt/debian-secure-gitlab-runner/admin-server/.env
ExecStart=/usr/bin/node server.js
Restart=on-failure
# allow binding to low port (80)
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=true
PrivateTmp=yes
PrivateDevices=yes
RestrictSUIDSGID=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
LockPersonality=yes

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable --now runner-admin

  # UFW allow only from LAN
  ufw allow from "${ADMIN_SUBNET}" to any port "${ADMIN_PORT}" proto tcp || true
fi

log "Install done."
log "Next: ./scripts/harden-systemd.sh, then ./scripts/set-concurrent.sh, then ./scripts/register-from-json.sh"
