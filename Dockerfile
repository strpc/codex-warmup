FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/root/.codex/bin:/usr/local/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    curl \
    cron \
    git \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY warmup.sh /usr/local/bin/warmup.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/warmup.sh /usr/local/bin/healthcheck.sh \
    && mkdir -p /root/.codex /codex-homes /workspace /run/codex-warmup

WORKDIR /workspace

HEALTHCHECK --interval=1m --timeout=10s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
