#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/claude-code-training"
COMPOSE_URL="https://raw.githubusercontent.com/ErikHellman/claude-code-training/main/docker-compose.yml"
LAUNCHER="$HOME/bin/claude-code-training"

# ── Helpers ────────────────────────────────────────────────────────────────
info()  { printf '\033[32m==>\033[0m %s\n' "$*"; }
error() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; }

# ── Check Docker ───────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    error "Docker is not installed or not on PATH."
    echo ""
    echo "Install one of the following and re-run this script:"
    echo ""
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "  OrbStack (recommended for Mac)  https://orbstack.dev"
        echo "  Docker Desktop                  https://www.docker.com/products/docker-desktop/"
        echo "  Rancher Desktop                 https://rancherdesktop.io"
    else
        echo "  Docker Desktop   https://www.docker.com/products/docker-desktop/"
        echo "  Docker Engine    https://docs.docker.com/engine/install/"
        echo "  Rancher Desktop  https://rancherdesktop.io"
    fi
    exit 1
fi

if ! docker info &>/dev/null; then
    error "Docker is installed but the daemon is not running."
    echo "Please start Docker (or OrbStack / Rancher Desktop) and re-run this script."
    exit 1
fi

# ── Set up directories ─────────────────────────────────────────────────────
info "Setting up $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR/workspace"

# ── Download compose file ──────────────────────────────────────────────────
info "Downloading docker-compose.yml ..."
if command -v curl &>/dev/null; then
    curl -fsSL "$COMPOSE_URL" -o "$INSTALL_DIR/docker-compose.yml"
elif command -v wget &>/dev/null; then
    wget -qO "$INSTALL_DIR/docker-compose.yml" "$COMPOSE_URL"
else
    error "curl or wget is required. Please install one and re-run."
    exit 1
fi

# ── Pull latest image ──────────────────────────────────────────────────────
info "Pulling latest image (this may take a while on first run) ..."
docker compose -f "$INSTALL_DIR/docker-compose.yml" -p claude-code-training pull

# ── Install launcher ───────────────────────────────────────────────────────
info "Installing launcher to $LAUNCHER ..."
mkdir -p "$HOME/bin"
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if ! docker info &>/dev/null; then
    echo "Error: Docker is not running. Please start Docker and try again." >&2
    exit 1
fi
exec docker compose \
    -f "$HOME/claude-code-training/docker-compose.yml" \
    -p claude-code-training \
    run --rm claude-code
EOF
chmod +x "$LAUNCHER"

# Add ~/bin to PATH in shell rc files if not already there
add_to_path() {
    local rcfile="$1"
    [[ -f "$rcfile" ]] || return
    grep -qF 'HOME/bin' "$rcfile" && return
    printf '\nexport PATH="$HOME/bin:$PATH"\n' >> "$rcfile"
    info "Added ~/bin to PATH in $rcfile"
}
add_to_path "$HOME/.zshrc"
add_to_path "$HOME/.bashrc"
add_to_path "$HOME/.bash_profile"
export PATH="$HOME/bin:$PATH"

# ── Launch ─────────────────────────────────────────────────────────────────
info "All done! Run 'claude-code-training' any time to start the environment."
echo ""
info "Starting Claude Code training environment ..."
echo ""
docker compose -f "$INSTALL_DIR/docker-compose.yml" -p claude-code-training run --rm claude-code
