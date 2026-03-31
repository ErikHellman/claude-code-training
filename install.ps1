#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME "claude-code-training"
$ComposeUrl = "https://raw.githubusercontent.com/ErikHellman/claude-code-training/main/docker-compose.yml"
$ComposeFile = Join-Path $InstallDir "docker-compose.yml"

function Write-Info  { param($msg) Write-Host "==> $msg" -ForegroundColor Green }
function Write-Err   { param($msg) Write-Host "Error: $msg" -ForegroundColor Red }

# ── Check Docker ───────────────────────────────────────────────────────────
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "Docker is not installed or not on PATH."
    Write-Host ""
    Write-Host "Install one of the following and re-run this script:"
    Write-Host ""
    Write-Host "  Docker Desktop   https://www.docker.com/products/docker-desktop/"
    Write-Host "  Rancher Desktop  https://rancherdesktop.io"
    Write-Host "  WSL2 + Docker    https://docs.docker.com/engine/install/"
    exit 1
}

$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker is installed but the daemon is not running."
    Write-Host "Please start Docker Desktop and re-run this script."
    exit 1
}

# ── Set up directories ─────────────────────────────────────────────────────
Write-Info "Setting up $InstallDir ..."
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir "workspace") | Out-Null

# ── Download compose file ──────────────────────────────────────────────────
Write-Info "Downloading docker-compose.yml ..."
Invoke-WebRequest -Uri $ComposeUrl -OutFile $ComposeFile -UseBasicParsing

# ── Pull latest image ──────────────────────────────────────────────────────
Write-Info "Pulling latest image (this may take a while on first run) ..."
docker compose -f $ComposeFile -p claude-code-training pull
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ── Launch ─────────────────────────────────────────────────────────────────
Write-Info "Starting Claude Code training environment ..."
Write-Host ""
docker compose -f $ComposeFile -p claude-code-training run --rm claude-code
