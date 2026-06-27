#!/bin/bash
# Pings every service endpoint and reports pass/fail.
# Exit code 0 = all checks passed, 1 = one or more failed.

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0

check() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"

  actual=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")

  if [ "$actual" = "$expected" ]; then
    echo -e "${GREEN}  pass${NC}  $name  ($url)"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}  fail${NC}  $name  ($url)  — expected $expected, got $actual"
    FAILED=$((FAILED + 1))
  fi
}

echo "Running deployment verification..."
echo ""

check "app root"          "http://localhost:3000/"           200
check "app /error"        "http://localhost:3000/error"      500
check "app /metrics"      "http://localhost:3000/metrics"    200
check "prometheus healthy" "http://localhost:9090/-/healthy" 200
check "loki ready"        "http://localhost:3100/ready"      200
check "grafana health"    "http://localhost:3001/api/health" 200

echo ""
echo "Results: $PASSED passed, $FAILED failed"

[ $FAILED -eq 0 ] || exit 1
