const express = require('express');
const winston = require('winston');

const app = express();
const port = process.env.PORT || 3000;

// Configure structured logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
  ],
});

app.get('/', (req, res) => {
  logger.info('Request received for /', { ip: req.ip, userAgent: req.get('User-Agent') });
  res.send('Hello, DevSecOps World!');
});

app.get('/success', (req, res) => {
    logger.info('Successful operation simulated.', { event_id: 'success-001' });
    res.status(200).send({ status: 'success', message: 'Operation completed successfully.' });
});

app.get('/failure', (req, res) => {
    logger.error('Failed operation simulated.', { event_id: 'failure-001', reason: 'database connection timeout' });
    res.status(500).send({ status: 'error', message: 'An error occurred during the operation.' });
});

app.listen(port, () => {
  logger.info(`Server listening on port ${port}`);
});
