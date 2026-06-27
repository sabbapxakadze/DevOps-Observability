const { test } = require('node:test');
const assert = require('node:assert/strict');
const supertest = require('supertest');
const app = require('../index.js');

test('GET / returns 200 with ok status', async () => {
  const res = await supertest(app).get('/');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
});

test('GET /error returns 500 with error status', async () => {
  const res = await supertest(app).get('/error');
  assert.equal(res.status, 500);
  assert.equal(res.body.status, 'error');
});

test('GET /metrics returns prometheus metrics', async () => {
  const res = await supertest(app).get('/metrics');
  assert.equal(res.status, 200);
  assert.ok(res.text.includes('app_requests_total'));
  assert.ok(res.text.includes('app_errors_total'));
});
