#!/usr/bin/env bash
set -euo pipefail

: "${CRON_SCHEDULE:=15 6 * * *}"
: "${CODEX_UPDATE_CRON_SCHEDULE:=0 4 * * *}"
: "${TZ:=Europe/Amsterdam}"
: "${CODEX_WARMUP_PROMPT:=Warmup only. Reply OK. Do not inspect or modify files.}"
: "${CODEX_SANDBOX:=read-only}"
: "${CODEX_TIMEOUT_SECONDS:=120}"
: "${CODEX_RETRIES:=2}"
: "${CODEX_RETRY_DELAY_SECONDS:=30}"
: "${CODEX_ACCOUNTS:=default}"

export TZ

validate_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "[entrypoint] ${name} must be a non-negative integer: ${value}" >&2
    exit 1
  fi
}

validate_cron_schedule() {
  local name="$1"
  local schedule="$2"
  local -a fields

  if [[ "$schedule" == *$'\n'* || "$schedule" == *$'\r'* ]]; then
    echo "[entrypoint] ${name} must be a single line" >&2
    exit 1
  fi

  read -r -a fields <<< "$schedule"
  if [[ "${#fields[@]}" -ne 5 ]]; then
    echo "[entrypoint] ${name} must contain exactly 5 fields: ${schedule}" >&2
    exit 1
  fi

  for field in "${fields[@]}"; do
    if [[ ! "$field" =~ ^[A-Za-z0-9_*/?,.-]+$ ]]; then
      echo "[entrypoint] ${name} contains unsupported characters: ${schedule}" >&2
      exit 1
    fi
  done
}

validate_accounts() {
  local accounts="$1"
  local -a names

  if [[ "$accounts" == *$'\n'* || "$accounts" == *$'\r'* ]]; then
    echo "[entrypoint] CODEX_ACCOUNTS must be a single line" >&2
    exit 1
  fi

  IFS=',' read -r -a names <<< "$accounts"
  for name in "${names[@]}"; do
    name="${name//[[:space:]]/}"
    if [[ -z "$name" || ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
      echo "[entrypoint] CODEX_ACCOUNTS contains an invalid account name: ${accounts}" >&2
      exit 1
    fi
  done
}

validate_timezone() {
  local timezone="$1"

  if [[ "$timezone" == *$'\n'* || "$timezone" == *$'\r'* ]]; then
    echo "[entrypoint] TZ must be a single line" >&2
    exit 1
  fi

  if [[ ! "$timezone" =~ ^[A-Za-z0-9_+./-]+$ ]]; then
    echo "[entrypoint] TZ contains unsupported characters: ${timezone}" >&2
    exit 1
  fi
}

validate_cron_schedule CRON_SCHEDULE "$CRON_SCHEDULE"
validate_cron_schedule CODEX_UPDATE_CRON_SCHEDULE "$CODEX_UPDATE_CRON_SCHEDULE"
validate_timezone "$TZ"
validate_integer CODEX_TIMEOUT_SECONDS "$CODEX_TIMEOUT_SECONDS"
validate_integer CODEX_RETRIES "$CODEX_RETRIES"
validate_integer CODEX_RETRY_DELAY_SECONDS "$CODEX_RETRY_DELAY_SECONDS"
validate_accounts "$CODEX_ACCOUNTS"

if ! command -v codex >/dev/null 2>&1; then
  echo "[entrypoint] codex binary was not found in PATH: $PATH" >&2
  exit 1
fi

mkdir -p /root/.codex /codex-homes /workspace /run/codex-warmup
chmod 700 /root/.codex || true

{
  printf 'export CODEX_WARMUP_PROMPT=%q\n' "$CODEX_WARMUP_PROMPT"
  printf 'export TZ=%q\n' "$TZ"
  printf 'export CODEX_SANDBOX=%q\n' "$CODEX_SANDBOX"
  printf 'export CODEX_TIMEOUT_SECONDS=%q\n' "$CODEX_TIMEOUT_SECONDS"
  printf 'export CODEX_RETRIES=%q\n' "$CODEX_RETRIES"
  printf 'export CODEX_RETRY_DELAY_SECONDS=%q\n' "$CODEX_RETRY_DELAY_SECONDS"
  printf 'export CODEX_ACCOUNTS=%q\n' "$CODEX_ACCOUNTS"
} > /etc/codex-warmup.env

chmod 600 /etc/codex-warmup.env

cat > /etc/cron.d/codex-warmup <<EOF
SHELL=/bin/bash
PATH=/root/.local/bin:/root/.codex/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TZ=${TZ}

${CRON_SCHEDULE} /usr/local/bin/warmup.sh > /proc/1/fd/1 2> /proc/1/fd/2
${CODEX_UPDATE_CRON_SCHEDULE} codex update > /proc/1/fd/1 2> /proc/1/fd/2
EOF

chmod 0644 /etc/cron.d/codex-warmup
crontab /etc/cron.d/codex-warmup

echo "[entrypoint] schedule: ${CRON_SCHEDULE}"
echo "[entrypoint] update schedule: ${CODEX_UPDATE_CRON_SCHEDULE}"
echo "[entrypoint] timezone: ${TZ}"
echo "[entrypoint] accounts: ${CODEX_ACCOUNTS}"
echo "[entrypoint] auth root: /codex-homes"
echo "[entrypoint] logs: container stdout/stderr"

IFS=',' read -r -a accounts <<< "$CODEX_ACCOUNTS"
for account in "${accounts[@]}"; do
  account="${account//[[:space:]]/}"
  if [[ ! -s "/codex-homes/${account}/auth.json" ]]; then
    echo "[entrypoint] warning: /codex-homes/${account}/auth.json is missing"
  fi
done

cron -f
