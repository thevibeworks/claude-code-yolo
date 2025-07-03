# syntax=docker/dockerfile:1.4

# Claude Code YOLO - Docker Image
# Provides a fully isolated Claude Code environment with sensible development tools

FROM ubuntu:24.04 AS base

LABEL maintainer="github.com/lroolle"
LABEL org.opencontainers.image.title="claude-code-yolo"
LABEL org.opencontainers.image.description="Safe Claude Code CLI with full dev environment"
LABEL org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    PATH=/root/.local/bin:/usr/local/go/bin:/usr/local/share/npm-global/bin:$PATH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget git gnupg lsb-release locales sudo \
        software-properties-common build-essential pkg-config libssl-dev \
        unzip zip bzip2 xz-utils tini gosu less man-db \
        python3-dev libffi-dev \
        jq ripgrep lsof tree make gcc g++ \
        openssh-client rsync \
        shellcheck bat fd-find \
        git procps psmisc zsh && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-dev python3.12-venv python3-pip pipx && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    locale-gen en_US.UTF-8

# Install language runtimes in parallel-friendly layers
FROM base AS runtimes

ARG NODE_MAJOR=22
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get -y clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/npm-global
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global

RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm install -g npm@latest pnpm && \
    npm cache clean --force

RUN curl -fsSL https://bun.sh/install | bash && \
    ln -s /root/.bun/bin/bun /usr/local/bin/bun

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN --mount=type=cache,target=/tmp/go-cache,sharing=locked \
    ARCH=$(dpkg --print-architecture) && \
    GO_ARCH=$([ "$ARCH" = "amd64" ] && echo "amd64" || echo "arm64") && \
    cd /tmp/go-cache && \
    wget -q https://go.dev/dl/go1.22.0.linux-${GO_ARCH}.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-${GO_ARCH}.tar.gz

FROM runtimes AS cloud-tools

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin

RUN --mount=type=cache,target=/tmp/aws-cache,sharing=locked \
    ARCH=$(dpkg --print-architecture) && \
    AWS_ARCH=$([ "$ARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    cd /tmp/aws-cache && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "awscliv2.zip" && \
    unzip -q awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

FROM cloud-tools AS tools

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    type -p wget >/dev/null || (apt-get update && apt-get install -y wget) && \
    mkdir -p -m 755 /etc/apt/keyrings && \
    wget -nv -O /tmp/githubcli-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    cat /tmp/githubcli-keyring.gpg > /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    mkdir -p -m 755 /etc/apt/sources.list.d && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    rm -f /tmp/githubcli-keyring.gpg

RUN --mount=type=cache,target=/tmp/delta-cache,sharing=locked \
    ARCH=$(dpkg --print-architecture) && \
    DELTA_ARCH=$([ "$ARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    cd /tmp/delta-cache && \
    wget -q https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu.tar.gz && \
    tar -xzf delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu.tar.gz && \
    mv delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu/delta /usr/local/bin/ && \
    rm -rf delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu*

ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_FACTOR=2 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=10000

# Claude Code installation - separate layer for easier version management
FROM tools AS claude-tools
ARG CLAUDE_CODE_VERSION=1.0.40
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} @mariozechner/claude-trace && \
    npm cache clean --force

# Final stage with shell setup
FROM claude-tools AS final

# Create non-root user for Claude execution
# Using 1001 as default to avoid conflicts with ubuntu user (usually 1000)
ENV CLAUDE_USER=claude \
    CLAUDE_UID=1001 \
    CLAUDE_GID=1001 \
    CLAUDE_HOME=/home/claude

RUN groupadd -g "$CLAUDE_GID" "$CLAUDE_USER" && \
    useradd -u "$CLAUDE_UID" -g "$CLAUDE_GID" -m -s /bin/zsh "$CLAUDE_USER" && \
    # Allow claude user to run sudo without password for development convenience
    echo "$CLAUDE_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$CLAUDE_USER" && \
    chmod 440 "/etc/sudoers.d/$CLAUDE_USER"

# Give claude user ownership of npm-global directory
RUN chown -R "$CLAUDE_UID:$CLAUDE_GID" /usr/local/share/npm-global

# Simple zsh setup
RUN echo 'export PATH=/root/.local/bin:/usr/local/go/bin:/usr/local/share/npm-global/bin:$PATH' >> ~/.zshrc
RUN echo 'export PATH=$HOME/.local/bin:/usr/local/go/bin:/usr/local/share/npm-global/bin:$PATH' >> "$CLAUDE_HOME/.zshrc" && \
    chown "$CLAUDE_USER:$CLAUDE_USER" "$CLAUDE_HOME/.zshrc"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chmod -R +x /usr/local/bin/scripts || true

WORKDIR /root

# Use tini as PID 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

CMD ["claude"]
