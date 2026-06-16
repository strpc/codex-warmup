#!/usr/bin/env bash
set -euo pipefail

source /etc/codex-warmup.env

cd /workspace

LOCK_FILE=/run/codex-warmup/warmup.lock

log() {
  local account="$1"
  shift
  echo "[$(date --iso-8601=seconds)] [${account}] $*"
}

activate_account() {
  local account="$1"
  local auth_dir="/codex-homes/${account}"
  local codex_auth_file="/root/.codex/auth.json"

  mkdir -p /root/.codex

  if [[ -L "$codex_auth_file" || -e "$codex_auth_file" ]]; then
    rm -f "$codex_auth_file"
  fi

  ln -s "${auth_dir}/auth.json" "$codex_auth_file"
}

run_account() {
  local account="$1"
  local auth_dir="/codex-homes/${account}"
  local attempt=1
  local max_attempts=$((CODEX_RETRIES + 1))
  local status=1

  if [[ ! -s "${auth_dir}/auth.json" ]]; then
    log "$account" "Missing ${auth_dir}/auth.json"
    return 1
  fi

  log "$account" "Starting Codex warmup"

  activate_account "$account"

  while (( attempt <= max_attempts )); do
    log "$account" "Attempt ${attempt}/${max_attempts}"

    set +e
    timeout "${CODEX_TIMEOUT_SECONDS}s" codex exec \
      --json \
      --skip-git-repo-check \
      --sandbox "$CODEX_SANDBOX" \
      "${CODEX_WARMUP_PROMPT}"
    status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
      log "$account" "Codex warmup finished"
      return 0
    fi

    log "$account" "Attempt ${attempt}/${max_attempts} failed with exit code ${status}"

    if (( attempt < max_attempts )); then
      sleep "$CODEX_RETRY_DELAY_SECONDS"
    fi

    attempt=$((attempt + 1))
  done

  log "$account" "Codex warmup failed after ${max_attempts} attempt(s)"
  return "$status"
}

main() {
  local total=0
  local successes=0
  local failures=0
  local account
  local -a accounts

  IFS=',' read -r -a accounts <<< "$CODEX_ACCOUNTS"

  for account in "${accounts[@]}"; do
    account="${account//[[:space:]]/}"
    [[ -z "$account" ]] && continue
    total=$((total + 1))

    if run_account "$account"; then
      successes=$((successes + 1))
    else
      failures=$((failures + 1))
    fi
  done

  log "summary" "accounts=${total} successes=${successes} failures=${failures}"

  if (( successes > 0 )); then
    return 0
  fi

  return 1
}

mkdir -p /run/codex-warmup

(
  if ! flock -n 9; then
    log "lock" "Previous warmup is still running; skipping this run"
    exit 0
  fi

  main
) 9>"$LOCK_FILE"
