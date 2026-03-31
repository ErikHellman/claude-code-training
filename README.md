# Claude Code Training Environment

A Docker container providing a consistent, ready-to-use terminal environment for courses on [Claude Code](https://claude.ai/code) — Anthropic's AI coding assistant for the terminal.

Students get a pre-configured shell with Claude Code and common development tools installed, so the course can focus on using Claude Code rather than setting it up.

## What's included

| Tool | Purpose |
|------|---------|
| [Claude Code](https://claude.ai/code) | AI coding assistant (the main subject of the course) |
| Node.js 22 + npm | JavaScript runtime |
| Python 3 + [uv](https://docs.astral.sh/uv/) | Python runtime and package manager |
| Go 1.23 | Go toolchain |
| Git + [GitHub CLI](https://cli.github.com/) (`gh`) | Version control and GitHub integration |
| [Oh My Zsh](https://ohmyz.sh/) | Shell with autosuggestions and syntax highlighting |
| `fzf`, `ripgrep`, `jq`, `bat` | Terminal productivity tools |
| `vim`, `nano` | In-container text editors |

## Student setup

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- A [Claude.ai](https://claude.ai) Pro, Max, Teams, or Enterprise subscription

### First-time setup

1. Create a folder for your work:
   ```bash
   mkdir claude-course && cd claude-course
   mkdir workspace
   ```

2. Download the compose file:
   ```bash
   curl -O https://raw.githubusercontent.com/ErikHellman/claude-code-training/main/docker-compose.yml
   ```

3. Start the container:
   ```bash
   docker compose run --rm claude-code
   ```
   Docker will pull the image automatically on first run (~1 GB).

4. Authenticate Claude Code (first time only):
   ```bash
   claude
   ```
   Claude Code will print a URL — open it in your browser, log in with your Claude.ai account, and you're done. Your login is saved in a Docker volume and persists across sessions.

### Day-to-day use

```bash
# Start a session
docker compose run --rm claude-code

# Your files live in ./workspace on your machine
# and at /workspace inside the container
```

Everything you create at `/workspace` inside the container is immediately visible in the `workspace/` folder on your host machine.

## Developer guide

### Repository structure

```
.
├── Dockerfile                        # Container definition
├── docker-compose.yml                # Compose config for students
├── .github/
│   └── workflows/
│       └── docker-publish.yml        # Builds and pushes image to ghcr.io on push to main
├── .dockerignore
└── .gitignore
```

### Building locally

```bash
docker build -t claude-code-training .
docker run -it --rm \
  -v claude-auth:/home/student/.claude \
  -v $(pwd)/workspace:/workspace \
  claude-code-training
```

### Adding tools

Add packages to the `apt-get install` block in `Dockerfile` for system tools, or add `RUN` steps after the student user is created for user-level installs. Keep changes in the appropriate section (root vs. student user).

### Updating Go

The Go version is controlled by a build argument:

```bash
docker build --build-arg GO_VERSION=1.24.0 -t claude-code-training .
```

To change the default, update the `ARG GO_VERSION=` line in `Dockerfile`.

### Publishing a new image

Push to `main` — GitHub Actions builds for both `linux/amd64` and `linux/arm64` and pushes to `ghcr.io/erikhellman/claude-code-training:latest` automatically.

The workflow file is at `.github/workflows/docker-publish.yml`.
