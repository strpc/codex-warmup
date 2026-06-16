.PHONY: build up down logs warmup config check

build:
	docker compose build

up:
	docker compose up -d --build --force-recreate

down:
	docker compose down

logs:
	docker compose logs -f

warmup:
	docker compose exec codex-warmup /usr/local/bin/warmup.sh

config:
	docker compose config

check:
	bash -n entrypoint.sh warmup.sh healthcheck.sh
	docker compose config >/dev/null
