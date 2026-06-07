#!/usr/bin/env bash
#
# update-compose-stacks.sh - keep all your Docker Compose stacks quietly up to date.
# No external dependencies: just Docker + standard shell utilities.
#
# For each Compose project Docker knows about:
#   1. pull images (downloads layers only if something changed)
#   2. if any image ID changed, `down` then `up -d` that project
#   3. after all projects are done, prune the now-dangling old images
#
# Usage:
#   ./update-compose-stacks.sh            # do it for real
#   ./update-compose-stacks.sh --dry-run  # report what would update, change nothing
#
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# --- prerequisites -----------------------------------------------------------
command -v docker >/dev/null || { warn "docker not found"; exit 1; }
docker compose version >/dev/null 2>&1 || { warn "docker compose v2 not available"; exit 1; }

# Discover Compose projects from container labels (covers running + stopped).
# Each line: "project-name|/path/to/first/compose.yml"; sort -u dedupes by project.
mapfile -t PROJECTS < <(
  docker ps -a --filter "label=com.docker.compose.project" \
    --format '{{.Label "com.docker.compose.project"}}|{{.Label "com.docker.compose.project.config_files"}}' \
    | sort -u
)

[[ ${#PROJECTS[@]} -eq 0 ]] && { log "No Compose projects found."; exit 0; }

UPDATED=0

# --- per-project update ------------------------------------------------------
for entry in "${PROJECTS[@]}"; do
  name="${entry%%|*}"
  config="${entry#*|}"; config="${config%%,*}"   # first config file if several
  dir="$(dirname "$config")"

  if [[ ! -f "$config" ]]; then
    warn "Skipping '$name': config file not found ($config)"
    continue
  fi

  log "Checking project '$name' ($config)"
  pushd "$dir" >/dev/null

  # Snapshot the image IDs this project uses (missing image => "absent:<name>").
  snapshot() {
    while read -r img; do
      [[ -z "$img" ]] && continue
      docker image inspect --format '{{.Id}}' "$img" 2>/dev/null || echo "absent:$img"
    done < <(docker compose -f "$config" config --images)
  }

  before="$(snapshot)"
  docker compose -f "$config" pull
  after="$(snapshot)"

  if [[ "$before" == "$after" ]]; then
    ok "  up to date"
  elif [[ $DRY_RUN -eq 1 ]]; then
    warn "  update available (dry-run, not applied)"
    UPDATED=$((UPDATED+1))
  else
    log "  new image(s) found - recreating"
    docker compose -f "$config" down
    docker compose -f "$config" up -d
    ok "  '$name' updated"
    UPDATED=$((UPDATED+1))
  fi

  popd >/dev/null
done

# --- cleanup -----------------------------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
  log "Dry-run complete: $UPDATED project(s) would update. No prune performed."
elif [[ $UPDATED -gt 0 ]]; then
  log "Pruning dangling images..."
  docker image prune -f
  ok "Done: $UPDATED project(s) updated and images pruned."
else
  ok "All projects already up to date. Nothing to prune."
fi
