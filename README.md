# DevOps Observability Lab — Final Project

A production-ready observability stack for a containerized Node.js application.
Covers metrics, logging, alerting, CI/CD, security scanning, health checks, and automated reliability tooling — deployable with a single command.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Quick Start](#quick-start)
3. [CI/CD Pipeline](#cicd-pipeline)
4. [Security Implementation](#security-implementation)
5. [Reliability Improvements](#reliability-improvements)
6. [Monitoring and Logging](#monitoring-and-logging)
7. [Alerting](#alerting)
8. [Scripts Reference](#scripts-reference)
9. [Branching Strategy](#branching-strategy)
10. [Screenshots](#screenshots)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Docker Network (observability)                    │
│                                                                      │
│  ┌──────────────────┐  scrape /metrics  ┌───────────────────────┐  │
│  │   Node.js App    │◄──────────────────│      Prometheus       │  │
│  │   (port 3000)    │                   │      (port 9090)      │  │
│  │                  │                   └───────────┬───────────┘  │
│  │  GET /           │                               │ metrics data  │
│  │  GET /error      │               ┌───────────────▼───────────┐  │
│  │  GET /metrics    │◄── browser    │         Grafana           │  │
│  └────────┬─────────┘               │        (port 3001)        │  │
│           │ stdout + file (volume)  └───────────────────────────┘  │
│           ▼                                       ▲                 │
│  ┌──────────────────┐  tail logs  ┌──────────────┴────────────┐   │
│  │   app-logs       │◄────────────│         Promtail          │   │
│  │  Docker Volume   │             └──────────────┬────────────┘   │
│  └──────────────────┘                            │ push to Loki    │
│                                   ┌──────────────▼────────────┐   │
│                                   │           Loki            │   │
│                                   │        (port 3100)        │   │
│                                   └───────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Services

| Service | Port | Role |
|---|---|---|
| Node.js App | 3000 | HTTP API + Prometheus metrics endpoint |
| Prometheus | 9090 | Metrics collection, alerting engine |
| Loki | 3100 | Log aggregation |
| Promtail | internal | Log shipper (tails file → pushes to Loki) |
| Grafana | 3001 | Dashboards, log explorer, alert UI |

All services share a Docker bridge network (`observability`) and persist data in named volumes.

---

## Quick Start

### Prerequisites
- Docker Desktop (includes Docker Compose)

### Linux / macOS
```bash
bash setup.sh
```

### Windows (PowerShell)
```powershell
.\setup.ps1
```

Both scripts:
1. Check that Docker is installed and running
2. Copy `.env.example` → `.env` (if not already present)
3. Run `docker compose up --build -d`
4. Wait 45 seconds for services to become healthy
5. Run `scripts/verify-deployment.sh` / `.ps1` to confirm all endpoints respond

After setup, access:

| Service | URL | Credentials |
|---|---|---|
| App | http://localhost:3000 | — |
| Grafana | http://localhost:3001 | admin / Admin123!@# |
| Prometheus | http://localhost:9090 | — |
| Loki API | http://localhost:3100 | — |

### Manual start (alternative)
```bash
docker compose up --build -d
```

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/ci.yml` and runs on every push to any branch and on pull requests to `main`.

### Jobs

#### `test` — Build and Test
| Step | Tool | Purpose |
|---|---|---|
| install | npm | install production + dev dependencies |
| audit | npm audit | fail if any **high** or **critical** CVEs in dependencies |
| lint | ESLint | enforce `eslint:recommended` code quality rules |
| test | node --test | run unit/integration tests via Node.js built-in test runner |

#### `security` — Security Scanning
| Step | Tool | Purpose |
|---|---|---|
| dockerfile lint | Hadolint | fail on Dockerfile best-practice errors |
| IaC validation | Checkov | scan `docker-compose.yml` and `Dockerfile` for misconfigurations |
| secrets scan | Gitleaks | scan entire git history for hardcoded secrets or credentials |
| image/fs scan | Trivy | scan `./app` filesystem for HIGH/CRITICAL CVEs (report only) |

Both jobs run in parallel. A push only fully passes when both jobs are green.

---

## Security Implementation

### Dependency Vulnerability Scanning
`npm audit --audit-level=high` runs on every CI push. The build fails if any dependency has a known HIGH or CRITICAL CVE. Fix by running `npm audit fix` locally.

### Dockerfile Linting (Hadolint)
Hadolint checks the `app/Dockerfile` against Docker best practices on every CI run. Configured to fail on **error**-level findings only (warnings are informational).

### Infrastructure as Code Scanning (Checkov)
Checkov validates both `docker-compose.yml` and `app/Dockerfile` against security policies (CIS benchmarks, misconfigurations). Runs in soft-fail mode — findings are reported in CI logs without blocking the build, allowing incremental remediation.

### Secrets Scanning (Gitleaks)
Gitleaks scans the full git commit history for patterns matching API keys, tokens, passwords, and private keys. Runs in CI on every push. To scan locally:
```bash
docker run --rm -v "$(pwd):/repo" zricethezav/gitleaks:latest detect --source /repo
```

### Container Filesystem Scanning (Trivy)
Trivy scans the `./app` directory for known CVEs in OS packages and language dependencies. Results are printed to the CI log. Exit code is set to `0` (report-only) since `npm audit` already gates the build on HIGH/CRITICAL findings.

### Secrets Management
Credentials are never committed to the repository. `.env` is listed in `.gitignore`. Use `.env.example` as a template:
```bash
cp .env.example .env
# edit .env with your values
```

---

## Reliability Improvements

### Docker Health Checks
Every service in `docker-compose.yml` has a `healthcheck` block that polls its HTTP health endpoint:

| Service | Health endpoint | Interval |
|---|---|---|
| app | `GET /` | 30s |
| prometheus | `GET /-/healthy` | 30s |
| loki | `GET /ready` | 30s |
| promtail | `GET /ready` (port 9080) | 30s |
| grafana | `GET /api/health` | 30s |

`depends_on` for `promtail` and `grafana` use `condition: service_healthy`, so they only start after their upstream services pass health checks.

The `app/Dockerfile` also includes a `HEALTHCHECK` instruction so `docker ps` reports health state directly.

### Rollback Procedure
To roll back the app to its previous git commit:
```bash
bash scripts/rollback.sh        # Linux/Mac
powershell scripts/rollback.ps1 # Windows
```
The script shows the current and previous commit, asks for confirmation, stops the stack, checks out the previous app code, and rebuilds.

### Incident Response
See [`docs/incident-runbook.md`](docs/incident-runbook.md) for playbooks covering:
- HighErrorRate alert (including rollback steps)
- ServiceDown alert
- HighRequestRate alert
- General recovery procedures (restart single service, full restart, full reset)

### Service Availability Objectives

| Service | Target | Max Downtime/Month |
|---|---|---|
| App | 99% | ~7 hours |
| Prometheus | 99% | ~7 hours |
| Grafana | 95% | ~36 hours |
| Loki | 95% | ~36 hours |

---

## Monitoring and Logging

### Metrics (Prometheus)
Prometheus scrapes the app's `/metrics` endpoint every 15 seconds. Metrics exposed:

| Metric | Type | Description |
|---|---|---|
| `app_requests_total` | Counter | Total HTTP requests received |
| `app_errors_total` | Counter | Total 500 responses returned |

Query examples in Prometheus / Grafana:
```promql
rate(app_requests_total[1m]) * 60   # requests per minute
rate(app_errors_total[1m]) * 60     # errors per minute
```

### Logging (Loki + Promtail)
The app writes every request as a single-line JSON log to both stdout and `/app/logs/app.log` (a shared Docker named volume). Promtail tails this file, parses the JSON, and promotes `level` and `endpoint` fields to indexed Loki labels.

**Log schema:**
```json
{"timestamp":"2026-06-27T10:00:00Z","level":"info","message":"Request received","endpoint":"/","method":"GET","status":200}
```

**Filter in Grafana Explore (Loki):**
```logql
{service="app", level="error"}
{service="app", endpoint="/error"}
```

### Grafana Dashboard
Auto-provisioned dashboard "Application Observability" with 6 panels:
- Total Requests (counter stat)
- Total Errors (counter stat, goes red at ≥1)
- Error Rate per minute (stat with thresholds: green <3, orange 3–5, red >5)
- Request Rate per second (stat)
- Requests Over Time (timeseries, 30-min window)
- Error Rate Over Time (timeseries with alert threshold line at 5/min)

---

## Alerting

### Alert Rules

Three Prometheus alert rules defined in `prometheus/alerts.yml`:

| Alert | Severity | Condition | For |
|---|---|---|---|
| HighErrorRate | critical | `rate(app_errors_total[1m]) * 60 > 5` | immediate |
| HighRequestRate | warning | `rate(app_requests_total[1m]) * 60 > 100` | 2 minutes |
| ServiceDown | critical | `up == 0` | 1 minute |

Grafana Unified Alerting also provisions a `CRITICAL - High Error Rate` rule that mirrors the HighErrorRate condition and is visible in the Grafana Alerting UI.

### How to trigger HighErrorRate

```powershell
# Windows — send 20 errors in rapid succession
for ($i = 0; $i -lt 20; $i++) {
    Invoke-WebRequest -Uri http://localhost:3000/error -UseBasicParsing | Out-Null
}
```
```bash
# Linux/Mac
for i in {1..20}; do curl -s http://localhost:3000/error > /dev/null; done
```

Then open **Grafana → Alerting → Alert Rules** — the rule changes to **Firing** within ~30 seconds.
Check Prometheus at http://localhost:9090/alerts for the native rule state.

---

## Scripts Reference

| Script | Platform | Purpose |
|---|---|---|
| `setup.sh` | Linux/Mac | Full one-command setup |
| `setup.ps1` | Windows | Full one-command setup |
| `scripts/verify-deployment.sh` | Linux/Mac | Ping all service endpoints, exit 1 on failure |
| `scripts/verify-deployment.ps1` | Windows | Same |
| `scripts/rollback.sh` | Linux/Mac | Roll back app to previous git commit |
| `scripts/rollback.ps1` | Windows | Same |

---

## Branching Strategy

This project follows a simplified **GitHub Flow**:

- `main` — always deployable; protected; only receives merges via pull request
- `feature/<name>` — short-lived branches for individual features or fixes
- `hotfix/<name>` — urgent fixes that go straight to a PR against `main`

All PRs must pass the full CI pipeline (both `test` and `security` jobs) before merging.

---

## Observability Analysis

### Why JSON Logging is More Efficient than Plain Text

Plain text logs are human-readable but machine-unfriendly. Parsing them requires fragile regex patterns that break whenever the message format changes. JSON logs treat every field as a first-class, typed key-value pair.

**Concrete advantages in this project:**

| Concern | Plain text | JSON (this project) |
|---|---|---|
| Parsing | Regex per log format | Zero-config — any JSON parser |
| Field extraction | Error-prone, format-dependent | `level`, `endpoint`, `status` extracted automatically by Promtail |
| Querying in Loki | Full-text search only | Label-based index: `{level="error"}`, `{endpoint="/error"}` |
| Log volume | Verbose free-text | Only structured fields — no repeated boilerplate |
| Tooling compatibility | Varies | Universal — Loki, Elasticsearch, Splunk, CloudWatch all ingest JSON natively |

Promtail's pipeline in this project reads the `level` and `endpoint` fields directly from JSON and promotes them to Loki index labels. This means filtering `{service="app", level="error"}` hits the index rather than scanning every log line — orders of magnitude faster at scale.

### Prometheus Metrics vs Log Aggregation — Technical Difference

These two systems answer fundamentally different questions and should not be treated as interchangeable.

**Prometheus (metrics)** stores time-series of numeric measurements. Each metric is a counter, gauge, histogram, or summary scraped at a fixed interval. It is optimised for aggregation: `rate()`, `sum()`, `avg()` across thousands of time points run in milliseconds. Prometheus does not store context — a counter incrementing tells you *how many* errors occurred, not *which request* caused them or *what the error message was*.

**Loki (log aggregation)** stores the full text of every log event with a timestamp and a set of labels. It is optimised for retrieval: given a label selector and a time range, return the exact log lines. It answers *why* and *what happened* — the stack trace, the user ID, the request payload.

**How they complement each other in this project:**

```
Prometheus alert fires: rate(app_errors_total[1m]) * 60 > 5
        ↓
"Something is wrong — the error rate is too high"
        ↓
Switch to Grafana Explore → Loki → {service="app", level="error"}
        ↓
"Here are the 12 exact error log lines, with endpoint and stack trace"
```

Metrics detect and alert; logs explain and diagnose. Running both is not redundant — it is the standard observability pattern (often called the three pillars: metrics, logs, traces).

### Long-Term Log Retention Without Exhausting Storage

Unbounded log accumulation will eventually fill any disk. The standard approach is a combination of retention policies, compaction, and tiered storage.

**Strategies:**

**1. Retention limits (implemented in this project)**
Loki's config (`loki/loki-config.yml`) sets `retention_period`. Chunks older than the limit are deleted automatically by the compactor. This bounds storage to a fixed time window.

**2. Log-level filtering before ingestion**
Promtail can drop `DEBUG` and `INFO` lines in high-volume environments, keeping only `WARN` and `ERROR` in long-term storage. This can reduce ingested volume by 90%+ with no loss of diagnostic value.

**3. Chunk compaction**
Loki compresses and merges raw chunks into larger, deduplicated blocks over time. The compactor runs on a schedule and reclaims space without manual intervention.

**4. Tiered / object storage**
For production workloads, Loki supports writing aged chunks to S3-compatible object storage (MinIO, AWS S3, GCS). Hot data stays on fast local disk; cold data moves to cheap object storage automatically. Cost per GB drops by ~10×.

**5. Structured log truncation**
Long stack traces and request bodies are the biggest contributors to log bloat. Truncating any single field over a defined byte limit at the application layer caps per-event size without losing the key structured fields.

In this lab setup, Loki retains logs in a local Docker volume. For a production deployment, strategy 1 (retention limit) + strategy 3 (compaction) + strategy 4 (object storage) would be combined to keep costs flat as the system scales.

---

## Screenshots

### Grafana Dashboard — Application Metrics
![Grafana Dashboard](./screenshots/grafana-dashboard.png)

### Grafana Explore — Filtered JSON Logs (Loki)
![Loki Logs](./screenshots/loki-logs.png)

### Grafana Alerting — Active Alert Rule
![Alert Rule](./screenshots/grafana-alert.png)

### CI Pipeline — GitHub Actions (test job)
![CI Pipeline](./screenshots/ci-pipeline.png)

### Security Scanning — GitHub Actions (security job)
![Security Scan](./screenshots/security-scan.png)
