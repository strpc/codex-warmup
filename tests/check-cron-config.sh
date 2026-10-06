#!/usr/bin/env bash
set -euo pipefail

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq -- "$expected" "$file"; then
    echo "Expected ${file} to contain: ${expected}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq -- "$unexpected" "$file"; then
    echo "Expected ${file} not to contain: ${unexpected}" >&2
    exit 1
  fi
}

assert_contains entrypoint.sh ': "${CODEX_UPDATE_CRON_SCHEDULE:=0 4 * * *}"'
assert_contains entrypoint.sh '${CODEX_UPDATE_CRON_SCHEDULE} codex update > /proc/1/fd/1 2> /proc/1/fd/2'
assert_contains entrypoint.sh '${CRON_SCHEDULE} /usr/local/bin/warmup.sh > /proc/1/fd/1 2> /proc/1/fd/2'
assert_not_contains entrypoint.sh '/var/log/codex-warmup/cron.log'

assert_contains docker-compose.yml 'CODEX_UPDATE_CRON_SCHEDULE: "${CODEX_UPDATE_CRON_SCHEDULE:-0 4 * * *}"'
assert_not_contains docker-compose.yml './logs:/var/log/codex-warmup'

assert_contains healthcheck.sh "grep -q 'codex update'"
