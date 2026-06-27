# Pings every service endpoint and reports pass/fail.
# Exit code 0 = all checks passed, 1 = one or more failed.

$passed = 0
$failed = 0

function Check-Endpoint {
    param($name, $url, $expected = 200)

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        $actual = $response.StatusCode
    } catch {
        $actual = $_.Exception.Response.StatusCode.value__
        if (-not $actual) { $actual = 0 }
    }

    if ($actual -eq $expected) {
        Write-Host "  pass  $name  ($url)" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  fail  $name  ($url)  -- expected $expected, got $actual" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "Running deployment verification..."
Write-Host ""

Check-Endpoint "app root"           "http://localhost:3000/"           200
Check-Endpoint "app /error"         "http://localhost:3000/error"      500
Check-Endpoint "app /metrics"       "http://localhost:3000/metrics"    200
Check-Endpoint "prometheus healthy" "http://localhost:9090/-/healthy"  200
Check-Endpoint "loki ready"         "http://localhost:3100/ready"      200
Check-Endpoint "grafana health"     "http://localhost:3001/api/health" 200

Write-Host ""
Write-Host "Results: $passed passed, $failed failed"

if ($failed -gt 0) { exit 1 }
