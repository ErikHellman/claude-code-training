FROM node:22-slim

# ── System packages ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        wget \
        zsh \
        vim \
        nano \
        fzf \
        ripgrep \
        jq \
        bat \
        python3 \
        python3-pip \
        ca-certificates \
        gnupg \
        less \
        locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ── GitHub CLI ─────────────────────────────────────────────────────────────
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ── Go ─────────────────────────────────────────────────────────────────────
ARG GO_VERSION=1.23.4
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
       | tar -C /usr/local -xz

# ── Student user ───────────────────────────────────────────────────────────
RUN useradd -m -s /bin/zsh -u 1000 student

# Set PATH and npm prefix for student globally so RUN commands below can use them
ENV PATH="/usr/local/go/bin:/home/student/.npm-global/bin:/home/student/.local/bin:${PATH}" \
    NPM_CONFIG_PREFIX=/home/student/.npm-global

USER student
WORKDIR /home/student

# ── Oh My Zsh + plugins ────────────────────────────────────────────────────
RUN RUNZSH=no CHSH=no sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && git clone --depth=1 \
         https://github.com/zsh-users/zsh-autosuggestions \
         /home/student/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone --depth=1 \
         https://github.com/zsh-users/zsh-syntax-highlighting \
         /home/student/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && sed -i 's/^plugins=(git)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc \
    && printf '\n# Tool paths\nexport PATH="/home/student/.npm-global/bin:/home/student/.local/bin:/usr/local/go/bin:$PATH"\n\n# Aliases\nalias bat="batcat"\nalias ll="ls -la"\n' >> ~/.zshrc

# ── uv (Python package manager) ────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# ── Claude Code ────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

CMD ["/bin/zsh"]
