#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/_lib.sh"
need_root
ensure_jq

CFG="$(dirname "$0")/../config.json"
[[ -f "$CFG" ]] || die "config.json not found."
CONCURRENT="$(read_json "$CFG" '.concurrent')"
[[ "$CONCURRENT" =~ ^[0-9]+$ ]] || die "Invalid concurrent value."

install -d -o gitlab-runner -g gitlab-runner /etc/gitlab-runner
[[ -f /etc/gitlab-runner/config.toml ]] || cp "$(dirname "$0")/../config/config.template.toml" /etc/gitlab-runner/config.toml

sed -i "s/^concurrent = .*/concurrent = ${CONCURRENT}/" /etc/gitlab-runner/config.toml
chown gitlab-runner:gitlab-runner /etc/gitlab-runner/config.toml
systemctl restart gitlab-runner
log "Set concurrent = ${CONCURRENT}"
