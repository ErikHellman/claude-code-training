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
        tree \
        tmux \
        fd-find \
        make \
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

# ── Binary tools: delta, lazygit, glow, eza ────────────────────────────────
# Fetches latest release of each tool from GitHub at build time.
# Arch mapping: dpkg amd64 -> x86_64, arm64 -> aarch64 (or arm64 where needed)
RUN DPKG_ARCH=$(dpkg --print-architecture) \
    AMD_ARCH=$(echo "$DPKG_ARCH" | sed 's/amd64/x86_64/;s/arm64/aarch64/') \
    # delta — syntax-highlighted git diffs
    && DELTA_VER=$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name') \
    && mkdir /tmp/delta \
    && curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/delta-${DELTA_VER}-${AMD_ARCH}-unknown-linux-gnu.tar.gz" \
       | tar -xz -C /tmp/delta \
    && find /tmp/delta -name delta -type f -exec install -m755 {} /usr/local/bin/delta \; \
    && rm -rf /tmp/delta \
    # lazygit — terminal git UI (arm64 uses "arm64", not "aarch64")
    && LG_VER=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name | ltrimstr("v")') \
    && LG_ARCH=$(echo "$DPKG_ARCH" | sed 's/amd64/x86_64/') \
    && mkdir /tmp/lazygit \
    && curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VER}/lazygit_${LG_VER}_Linux_${LG_ARCH}.tar.gz" \
       | tar -xz -C /tmp/lazygit \
    && install -m755 /tmp/lazygit/lazygit /usr/local/bin/lazygit \
    && rm -rf /tmp/lazygit \
    # glow — markdown viewer (arm64 uses "arm64")
    && GLOW_VER=$(curl -fsSL https://api.github.com/repos/charmbracelet/glow/releases/latest | jq -r '.tag_name | ltrimstr("v")') \
    && GLOW_ARCH=$(echo "$DPKG_ARCH" | sed 's/amd64/x86_64/') \
    && mkdir /tmp/glow \
    && curl -fsSL "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VER}/glow_${GLOW_VER}_Linux_${GLOW_ARCH}.tar.gz" \
       | tar -xz -C /tmp/glow \
    && find /tmp/glow -name glow -type f -exec install -m755 {} /usr/local/bin/glow \; \
    && rm -rf /tmp/glow \
    # eza — modern ls replacement
    && EZA_VER=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest | jq -r '.tag_name | ltrimstr("v")') \
    && mkdir /tmp/eza \
    && curl -fsSL "https://github.com/eza-community/eza/releases/download/v${EZA_VER}/eza_${AMD_ARCH}-unknown-linux-gnu.tar.gz" \
       | tar -xz -C /tmp/eza \
    && find /tmp/eza -name eza -type f -exec install -m755 {} /usr/local/bin/eza \; \
    && rm -rf /tmp/eza

# ── Student user ───────────────────────────────────────────────────────────
RUN useradd -m -s /bin/zsh -u 1000 student

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
    && printf '\n# Tool paths\nexport PATH="/home/student/.npm-global/bin:/home/student/.local/bin:/usr/local/go/bin:$PATH"\n\n# Aliases\nalias bat="batcat"\nalias ls="eza"\nalias ll="eza -la"\nalias la="eza -la"\nalias fd="fdfind"\nalias lg="lazygit"\n\n# Zoxide (smart cd — use "z" instead of "cd")\neval "$(zoxide init zsh)"\n' >> ~/.zshrc

# ── Configure delta as git pager ───────────────────────────────────────────
RUN git config --global core.pager delta \
    && git config --global interactive.diffFilter "delta --color-only" \
    && git config --global delta.navigate true \
    && git config --global delta.dark true \
    && git config --global merge.conflictstyle diff3 \
    && git config --global diff.colorMoved default

# ── uv (Python package manager) ────────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# ── zoxide (smart directory jumping) ──────────────────────────────────────
RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# ── Claude Code ────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

CMD ["/bin/zsh"]
