const express = require('express');
const client = require('prom-client');
const winston = require('winston');

const app = express();
const port = process.env.PORT || 3000;
const register = new client.Registry();

client.collectDefaultMetrics({ register });

// Configure structured logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
  ],
});

const requestCounter = new client.Counter({
  name: 'shared_app_http_requests_total',
  help: 'Total number of HTTP requests handled by shared-app',
  labelNames: ['route', 'method', 'status_code'],
  registers: [register],
});

function recordRequest(route, method, statusCode) {
  requestCounter.inc({ route, method, status_code: String(statusCode) });
}

app.get('/', (req, res) => {
  logger.info('Request received for /', { ip: req.ip, userAgent: req.get('User-Agent') });
  recordRequest('/', req.method, 200);
  res.send('Hello, DevSecOps World!');
});

app.get('/success', (req, res) => {
    logger.info('Successful operation simulated.', { event_id: 'success-001' });
    recordRequest('/success', req.method, 200);
    res.status(200).send({ status: 'success', message: 'Operation completed successfully.' });
});

app.get('/failure', (req, res) => {
    logger.error('Failed operation simulated.', { event_id: 'failure-001', reason: 'database connection timeout' });
    recordRequest('/failure', req.method, 500);
    res.status(500).send({ status: 'error', message: 'An error occurred during the operation.' });
});

app.get('/healthz', (req, res) => {
  recordRequest('/healthz', req.method, 200);
  res.status(200).send({ status: 'ok' });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  recordRequest('/metrics', req.method, 200);
  res.send(metrics);
});

app.listen(port, () => {
  logger.info(`Server listening on port ${port}`);
});
