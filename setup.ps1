# One-command setup for Windows.
# Checks prerequisites, copies env template, starts the stack,
# waits for health checks, then runs deployment verification.
$ErrorActionPreference = "Stop"

function ok   { Write-Host "  ok   $args" -ForegroundColor Green }
function fail { Write-Host " fail  $args" -ForegroundColor Red; exit 1 }

Write-Host "================================================"
Write-Host "  DevOps Observability Lab - Setup"
Write-Host "================================================"
Write-Host ""

Write-Host "Checking prerequisites..."

try { docker --version | Out-Null; ok "docker found" }
catch { fail "docker is not installed" }

try { docker compose version | Out-Null; ok "docker compose found" }
catch { fail "docker compose plugin not available" }

try { docker info | Out-Null; ok "docker daemon running" }
catch { fail "docker daemon is not running - start Docker Desktop" }

Write-Host ""
Write-Host "Preparing environment..."

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    ok "created .env from .env.example"
} else {
    ok ".env already exists, skipping"
}

Write-Host ""
Write-Host "Starting the stack..."
docker compose up --build -d

Write-Host ""
Write-Host "Waiting 45 seconds for services to become healthy..."
Start-Sleep -Seconds 45

Write-Host ""
& "$PSScriptRoot\scripts\verify-deployment.ps1"

Write-Host ""
Write-Host "================================================"
Write-Host "  Stack is ready"
Write-Host "  App:        http://localhost:3000"
Write-Host "  Grafana:    http://localhost:3001  (admin / admin)"
Write-Host "  Prometheus: http://localhost:9090"
Write-Host "================================================"
