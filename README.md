# codex-warmup

Start a Codex usage window before you sit down to work.

`codex-warmup` runs a tiny scheduled Codex CLI prompt from Docker. The default prompt is intentionally boring:

```text
Warmup only. Reply OK. Do not inspect or modify files.
```

It does not bypass limits and does not create extra quota. It just nudges the first window to start earlier.

## Why ☕

If your first real Codex message happens at 9:30, that is when the usage window starts. Sometimes that means the first window ends at an awkward time.

Same workday, different window timing:

```text
6am    7     8     9    10    11    12    1pm    2     3     4     5    6pm
 |     |     |     |     |     |     |     |     |     |     |     |     |

Without warmup:              [============ window 1 ============]
                              work ~8:30am-11am  ░░░ dead ░░░
                                                               [============ window 2 ============]
                                                                         work ~1:30pm-6pm

With warmup:    cron trigger
                    │
                    ▼
                [========== window 1 =========]
                 ░░ idle ░░  work ~8:30am-11am
                                              [========== window 2 =========]
                                                      work ~11am-4pm
                                                                            [== win 3 ==]
                                                                            work ~4pm-6pm
```

Why Docker:

- no Codex CLI install on the host
- no host cron setup
- auth lives in local `codex-homes/` folders
- logs go to `logs/`
- `.dockerignore` keeps auth, logs, `.env`, and workspace data out of the image

## Quick Start 🚀

Requirements:

- Docker
- Docker Compose
- an existing Codex CLI login on the machine you copy auth from
- an always-on host, VPS, or home server

Create config:

```bash
cp .env.example .env
```

Copy your Codex auth into the container account folder:

```bash
mkdir -p codex-homes/default
cp ~/.codex/auth.json ./codex-homes/default/auth.json
chmod 700 codex-homes codex-homes/default
chmod 600 codex-homes/default/auth.json
```

Start it:

```bash
make up
```

Or without Make:

```bash
docker compose up -d --build --force-recreate
```

Run a manual warmup test:

```bash
make warmup
```

Successful output looks like this:

```text
[default] Starting Codex warmup
{"type":"item.completed","item":{"type":"agent_message","text":"OK"}}
[default] Codex warmup finished
[summary] accounts=1 successes=1 failures=0
```

## Configuration ⚙️

Edit `.env`:

```bash
CRON_SCHEDULE="15 6 * * *"
TZ="Europe/Amsterdam"
CODEX_WARMUP_PROMPT="Warmup only. Reply OK. Do not inspect or modify files."
CODEX_SANDBOX="read-only"
CODEX_TIMEOUT_SECONDS="120"
CODEX_RETRIES="2"
CODEX_RETRY_DELAY_SECONDS="30"
CODEX_ACCOUNTS="default"
```

The default schedule runs every day at 6:15 AM in `Europe/Amsterdam`.

Need a cron expression? Use https://crontab.guru/.

Examples:

```bash
# Every day at 6:15 AM
CRON_SCHEDULE="15 6 * * *"

# Every day at 6:00 AM
CRON_SCHEDULE="0 6 * * *"

# Weekdays at 6:15 AM
CRON_SCHEDULE="15 6 * * 1-5"
```

After changing `.env`, recreate the container:

```bash
make up
```

Docker Compose reads `.env` when it creates the container. A running container will not automatically pick up edits.

To preview the effective Compose config:

```bash
make config
```

## Multiple Accounts

Put each account in its own directory:

```text
codex-homes/
  personal/auth.json
  work/auth.json
```

Then set:

```bash
CODEX_ACCOUNTS="personal,work"
```

Warmup runs accounts sequentially. If one account fails, the others still run. The job succeeds if at least one account succeeds.

## Logs And Checks 🔎

Container logs:

```bash
docker compose logs -f
```

Cron logs:

```bash
tail -f logs/cron.log
```

Container status and healthcheck:

```bash
docker compose ps
```

Installed cron entry:

```bash
docker compose exec codex-warmup crontab -l
```

Static checks before changing the project:

```bash
make check
```

## Safety Notes 🔐

Treat every `codex-homes/*/auth.json` like a password.

Do not mount your desktop `~/.codex` directly into the container. Copy only the account auth file you want this warmup job to use.

Good:

```text
./codex-homes/default/auth.json -> /root/.codex/auth.json inside the container
```

Bad:

```yaml
volumes:
  - ~/.codex:/root/.codex
```

For warmup-only usage, keep `workspace/` empty and leave `CODEX_SANDBOX="read-only"`.

Internally, the script runs `codex exec --skip-git-repo-check` because `/workspace` is intentionally allowed to be empty.

## Troubleshooting

Auth missing:

```bash
ls -l codex-homes/*/auth.json
docker compose exec codex-warmup env | grep CODEX_ACCOUNTS
```

Wrong schedule or timezone:

```bash
docker compose exec codex-warmup date
docker compose exec codex-warmup crontab -l
```

Codex binary missing after an upstream installer change:

```bash
docker compose build --no-cache
make up
```

All accounts failed:

```bash
make warmup
```

If auth is the problem, refresh `codex-homes/<account>/auth.json` from a machine where `codex login status` works.

## Inspiration

Inspired by `claude-warmup`: https://github.com/vdsmon/claude-warmup
