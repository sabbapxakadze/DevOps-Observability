const express = require('express');
const client = require('prom-client');
const fs = require('fs');

const app = express();
const register = new client.Registry();

const requestsTotal = new client.Counter({
  name: 'app_requests_total',
  help: 'Total number of requests received',
  registers: [register],
});

const errorsTotal = new client.Counter({
  name: 'app_errors_total',
  help: 'Total number of errors returned',
  registers: [register],
});

const LOG_FILE = '/app/logs/app.log';

function log(level, message, extra = {}) {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    ...extra,
  });
  console.log(entry);
  try {
    fs.appendFileSync(LOG_FILE, entry + '\n');
  } catch (err) {
    console.error('log write failed:', err.message);
  }
}

app.get('/', (req, res) => {
  requestsTotal.inc();
  log('info', 'Request received', { endpoint: '/', method: req.method, status: 200 });
  res.json({ status: 'ok', message: 'Hello from the observability app!' });
});

app.get('/error', (req, res) => {
  requestsTotal.inc();
  errorsTotal.inc();
  log('error', 'Error endpoint hit', { endpoint: '/error', method: req.method, status: 500 });
  res.status(500).json({ status: 'error', message: 'Simulated error' });
});

app.get('/dashboard', (req, res) => {
  requestsTotal.inc();
  log('info', 'Request received', { endpoint: '/dashboard', method: req.method, status: 200 });
  res.send(`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Observability App</title>
<style>
  :root { color-scheme: dark; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: -apple-system, Segoe UI, Roboto, sans-serif;
    background: #0f1117;
    color: #e6e6e6;
  }
  .card {
    background: #171a23;
    border: 1px solid #262a36;
    border-radius: 12px;
    padding: 2.5rem 3rem;
    max-width: 480px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.35);
  }
  h1 { margin: 0 0 0.25rem; font-size: 1.5rem; }
  .status {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.85rem;
    color: #4ade80;
    margin-bottom: 1.5rem;
  }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: #4ade80; }
  ul { list-style: none; padding: 0; margin: 0; }
  li + li { margin-top: 0.6rem; }
  a {
    display: block;
    padding: 0.7rem 1rem;
    border-radius: 8px;
    background: #1f2330;
    color: #e6e6e6;
    text-decoration: none;
    font-size: 0.95rem;
    transition: background 0.15s ease;
  }
  a:hover { background: #2a2f40; }
  .hint { color: #8a8f9c; font-size: 0.8rem; margin-top: 1.5rem; }
</style>
</head>
<body>
  <div class="card">
    <h1>Observability App</h1>
    <div class="status"><span class="dot"></span> running</div>
    <ul>
      <li><a href="/">GET / — health endpoint</a></li>
      <li><a href="/error">GET /error — simulate an error</a></li>
      <li><a href="/metrics">GET /metrics — Prometheus metrics</a></li>
      <li><a href="http://localhost:3001" target="_blank" rel="noopener">Grafana (:3001)</a></li>
      <li><a href="http://localhost:9090" target="_blank" rel="noopener">Prometheus (:9090)</a></li>
    </ul>
    <div class="hint">This page is just a landing view — the API responses at / and /error remain JSON.</div>
  </div>
</body>
</html>`);
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

if (require.main === module) {
  app.listen(3000, () => {
    log('info', 'Application started', { port: 3000 });
  });
}

module.exports = app;
