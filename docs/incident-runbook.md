# Incident Response Runbook

This document describes how to respond to alerts and failures in the observability stack.

## Alert Definitions

| Alert | Severity | Condition | Meaning |
|---|---|---|---|
| HighErrorRate | critical | errors/min > 5 | App is returning too many 500s |
| HighRequestRate | warning | requests/min > 100 | Unusual traffic spike |
| ServiceDown | critical | up == 0 for 1m | Prometheus cannot reach a scrape target |

---

## Playbooks

### HighErrorRate (critical)

**Where to look first:**
1. Grafana → Explore → Loki → `{service="app", level="error"}` — read the error messages
2. Grafana → Dashboard → "Error Rate Over Time" panel — see when it started
3. `docker compose logs app --tail=50` — raw container logs

**Likely causes and fixes:**

| Cause | Fix |
|---|---|
| Code bug introduced in recent deploy | Run `scripts/rollback.sh` (Linux) or `scripts/rollback.ps1` (Windows) |
| Downstream dependency failure | Check external services; add retries or circuit breaker |
| Bad configuration | Review recent config changes; restart with previous config |

**Steps:**
```bash
# 1. Check recent logs
docker compose logs app --tail=100 --follow

# 2. If a bad deploy caused it, roll back
bash scripts/rollback.sh        # Linux/Mac
# or
powershell scripts/rollback.ps1 # Windows

# 3. Verify the stack is healthy after rollback
bash scripts/verify-deployment.sh
```

---

### ServiceDown (critical)

**Where to look first:**
1. Prometheus → http://localhost:9090/targets — see which target is down
2. `docker compose ps` — check container status

**Steps:**
```bash
# 1. Identify which service is down
docker compose ps

# 2. Check its logs
docker compose logs <service-name> --tail=50

# 3. Restart the specific service
docker compose restart <service-name>

# 4. If that fails, full restart
docker compose down && docker compose up -d

# 5. Confirm recovery
bash scripts/verify-deployment.sh
```

---

### HighRequestRate (warning)

This alert fires at 100 req/min but does not indicate an error. It may be:
- Legitimate traffic spike (no action needed)
- A scraper or bot (consider rate limiting)
- A misconfigured client hammering an endpoint

**Steps:**
1. Grafana → Dashboard → "Requests Over Time" — identify which endpoint
2. If traffic is legitimate, no action needed — monitor for error rate increase
3. If traffic is malicious, consider adding rate limiting to the app

---

## General Recovery Procedures

### Restart a single service
```bash
docker compose restart <service>
# services: app, prometheus, loki, promtail, grafana
```

### Restart the full stack (keeps data)
```bash
docker compose down && docker compose up -d
```

### Full reset (DESTROYS all stored data)
```bash
docker compose down -v && docker compose up --build -d
```

### Check all service health
```bash
docker compose ps
bash scripts/verify-deployment.sh
```

### Roll back the app to previous version
```bash
bash scripts/rollback.sh        # Linux/Mac
powershell scripts/rollback.ps1 # Windows
```

---

## Service Availability Objectives

| Service | Target Uptime | Max Downtime/Month |
|---|---|---|
| App | 99% | ~7 hours |
| Prometheus | 99% | ~7 hours |
| Grafana | 95% | ~36 hours |
| Loki | 95% | ~36 hours |

These are lab targets. In production, critical services should target 99.9%+ (< 45 min/month).
