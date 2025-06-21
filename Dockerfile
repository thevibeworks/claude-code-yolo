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
    PATH=/root/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:/usr/local/rustup/bin:$PATH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget git gnupg lsb-release locales sudo \
        software-properties-common build-essential pkg-config libssl-dev \
        unzip zip bzip2 xz-utils tini gosu less man-db \
        python3-dev libffi-dev libxml2-dev libxslt1-dev libyaml-dev \
        jq yq httpie tree fd-find ripgrep fzf htop lsof \
        vim neovim nano make cmake gcc g++ clang llvm \
        openssh-client rsync iputils-ping netcat-openbsd dnsutils \
        traceroute tcpdump strace ltrace gdb valgrind \
        tig bat eza tmux screen direnv \
        clang-format clang-tidy cppcheck shellcheck \
        black mypy pylint flake8 isort \
        zsh && \
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
    npm install -g npm@latest yarn pnpm && \
    npm cache clean --force

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN --mount=type=cache,target=/tmp/go-cache,sharing=locked \
    ARCH=$(dpkg --print-architecture) && \
    GO_ARCH=$([ "$ARCH" = "amd64" ] && echo "amd64" || echo "arm64") && \
    cd /tmp/go-cache && \
    wget -q https://go.dev/dl/go1.22.0.linux-${GO_ARCH}.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-${GO_ARCH}.tar.gz

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

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

RUN --mount=type=cache,target=/tmp/delta-cache,sharing=locked \
    ARCH=$(dpkg --print-architecture) && \
    DELTA_ARCH=$([ "$ARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    cd /tmp/delta-cache && \
    wget -q https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu.tar.gz && \
    tar -xzf delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu.tar.gz && \
    mv delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu/delta /usr/local/bin/ && \
    rm -rf delta-0.18.2-${DELTA_ARCH}-unknown-linux-gnu*

RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm config set prefix /usr/local && \
    npm install -g @anthropic-ai/claude-code@latest @mariozechner/claude-trace && \
    npm cache clean --force

ENV NPM_CONFIG_FETCH_RETRIES=5 \
    NPM_CONFIG_FETCH_RETRY_FACTOR=2 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=10000

# Final stage with shell setup
FROM tools AS final

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

# Install Oh My Zsh and plugins for root
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install Oh My Zsh for claude-user
USER $CLAUDE_USER
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
USER root

# Create optimized .zshrc for root
RUN echo 'export ZSH="$HOME/.oh-my-zsh"' > ~/.zshrc && \
    echo 'ZSH_THEME="robbyrussell"' >> ~/.zshrc && \
    echo 'plugins=(git docker python golang rust node npm yarn aws zsh-autosuggestions zsh-syntax-highlighting)' >> ~/.zshrc && \
    echo 'source $ZSH/oh-my-zsh.sh' >> ~/.zshrc && \
    echo 'export PATH=/root/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH' >> ~/.zshrc

# Create optimized .zshrc for claude-user
RUN echo 'export ZSH="$HOME/.oh-my-zsh"' > "$CLAUDE_HOME/.zshrc" && \
    echo 'ZSH_THEME="robbyrussell"' >> "$CLAUDE_HOME/.zshrc" && \
    echo 'plugins=(git docker python golang rust node npm yarn aws zsh-autosuggestions zsh-syntax-highlighting)' >> "$CLAUDE_HOME/.zshrc" && \
    echo 'source $ZSH/oh-my-zsh.sh' >> "$CLAUDE_HOME/.zshrc" && \
    echo 'export PATH=$HOME/.local/bin:/usr/local/go/bin:/usr/local/cargo/bin:$PATH' >> "$CLAUDE_HOME/.zshrc" && \
    chown "$CLAUDE_USER:$CLAUDE_USER" "$CLAUDE_HOME/.zshrc"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chmod -R +x /usr/local/bin/scripts || true

WORKDIR /root

# Use tini as PID 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

CMD ["claude"]
