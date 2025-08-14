#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/_lib.sh"
need_root
ensure_jq

CFG="$(dirname "$0")/../config.json"
[[ -f "$CFG" ]] || die "config.json not found."

GITLAB_URL="$(read_json "$CFG" '.gitlab_url')"
BUILDS_DIR="$(read_json "$CFG" '.builds_dir')"
CACHE_DIR="$(read_json "$CFG" '.cache_dir')"

RUN_UNTAGGED="$(read_json "$CFG" '.security.run_untagged')"
LOCKED="$(read_json "$CFG" '.security.locked')"
ACCESS_LEVEL="$(read_json "$CFG" '.security.access_level')"

install -d -o gitlab-runner -g gitlab-runner /etc/gitlab-runner
[[ -f /etc/gitlab-runner/config.toml ]] || cp "$(dirname "$0")/../config/config.template.toml" /etc/gitlab-runner/config.toml
chown gitlab-runner:gitlab-runner /etc/gitlab-runner/config.toml

COUNT="$(jq '.runners | length' "$CFG")"
(( COUNT > 0 )) || die "No runners defined in config.json"

for i in $(seq 0 $((COUNT-1))); do
  NAME="$(jq -r ".runners[$i].name" "$CFG")"
  TAGS="$(jq -r ".runners[$i].tags | join(\",\")" "$CFG")"
  TOKEN="$(jq -r ".runners[$i].registration_token" "$CFG")"
  [[ -n "$NAME" && -n "$TAGS" && -n "$TOKEN" ]] || die "Runner $i missing name/tags/token."

  log "Registering runner: $NAME with tags: $TAGS"
  echo "{\"runner\":\"$NAME\",\"tags\":\"$TAGS\",\"registration_token\":\"$TOKEN\"}" | mask | sed 's/^/[info] /'

  sudo -u gitlab-runner \
    gitlab-runner register \
      --non-interactive \
      --url "$GITLAB_URL" \
      --registration-token "$TOKEN" \
      --name "$NAME" \
      --executor "shell" \
      --tag-list "$TAGS" \
      --builds-dir "$BUILDS_DIR" \
      --cache-dir "$CACHE_DIR" \
      --locked="$LOCKED" \
      --run-untagged="$RUN_UNTAGGED" \
      --access-level="$ACCESS_LEVEL"
done

systemctl restart gitlab-runner
log "All runners registered."
