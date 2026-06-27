#!/bin/bash
# One-command setup: checks prerequisites, copies env template, starts the stack,
# waits for health checks, then runs deployment verification.
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ok${NC}  $1"; }
fail() { echo -e "${RED} fail${NC}  $1"; exit 1; }

echo "================================================"
echo "  DevOps Observability Lab — Setup"
echo "================================================"
echo ""

echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1          && ok "docker found"          || fail "docker is not installed"
docker compose version >/dev/null 2>&1     && ok "docker compose found"  || fail "docker compose plugin not available"
docker info >/dev/null 2>&1                && ok "docker daemon running" || fail "docker daemon is not running — start Docker Desktop"

echo ""
echo "Preparing environment..."
if [ ! -f .env ]; then
  cp .env.example .env
  ok "created .env from .env.example"
else
  ok ".env already exists, skipping"
fi

echo ""
echo "Starting the stack..."
docker compose up --build -d

echo ""
echo "Waiting 45 seconds for services to become healthy..."
sleep 45

echo ""
bash scripts/verify-deployment.sh

echo ""
echo "================================================"
echo "  Stack is ready"
echo "  App:        http://localhost:3000"
echo "  Grafana:    http://localhost:3001  (admin / admin)"
echo "  Prometheus: http://localhost:9090"
echo "================================================"
