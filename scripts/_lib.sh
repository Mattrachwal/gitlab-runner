#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log() { printf "[%(%F %T)T] %s\n" -1 "$*"; }
die() { printf "ERROR: %s\n" "$*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || die "Run as root (sudo)."; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_jq() {
  if ! have_cmd jq; then
    log "Installing jq..."
    apt-get update -y && apt-get install -y jq
  fi
}

read_json() {
  local file="$1" jqexpr="$2"
  jq -er "$jqexpr" "$file"
}

mask() { sed -E 's/(registration_token":\s*")([^"]+)"/\1********"/g'; }
