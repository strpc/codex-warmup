#!/usr/bin/env bash
set -euo pipefail

: "${CODEX_ACCOUNTS:=default}"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex binary was not found" >&2
  exit 1
fi

if [[ ! -s /etc/codex-warmup.env ]]; then
  echo "/etc/codex-warmup.env is missing" >&2
  exit 1
fi

if ! crontab -l 2>/dev/null | grep -q '/usr/local/bin/warmup.sh'; then
  echo "codex warmup cron entry is missing" >&2
  exit 1
fi

IFS=',' read -r -a accounts <<< "$CODEX_ACCOUNTS"

for account in "${accounts[@]}"; do
  account="${account//[[:space:]]/}"
  if [[ -n "$account" && -s "/codex-homes/${account}/auth.json" ]]; then
    exit 0
  fi
done

echo "no configured account has auth.json" >&2
exit 1
