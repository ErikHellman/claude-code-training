#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME "claude-code-training"
$ComposeUrl = "https://raw.githubusercontent.com/ErikHellman/claude-code-training/main/docker-compose.yml"
$ComposeFile = Join-Path $InstallDir "docker-compose.yml"
$BinDir     = Join-Path $HOME "bin"
$Launcher   = Join-Path $BinDir "claude-code-training.bat"

function Write-Info { param($msg) Write-Host "==> $msg" -ForegroundColor Green }
function Write-Err  { param($msg) Write-Host "Error: $msg" -ForegroundColor Red }

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

docker info 2>&1 | Out-Null
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

# ── Install launcher ───────────────────────────────────────────────────────
Write-Info "Installing launcher to $Launcher ..."
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

@"
@echo off
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop and try again.
    exit /b 1
)
docker compose -f "%USERPROFILE%\claude-code-training\docker-compose.yml" -p claude-code-training run --rm claude-code
"@ | Set-Content -Path $Launcher -Encoding ASCII

# Add ~/bin to user PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$BinDir;$userPath", "User")
    $env:PATH = "$BinDir;$env:PATH"
    Write-Info "Added $BinDir to your PATH."
}

# ── Launch ─────────────────────────────────────────────────────────────────
Write-Info "All done! Run 'claude-code-training' from any new terminal to start."
Write-Host ""
Write-Info "Starting Claude Code training environment ..."
Write-Host ""
docker compose -f $ComposeFile -p claude-code-training run --rm claude-code
