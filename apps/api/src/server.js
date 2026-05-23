const http = require('http');
const { randomUUID } = require('crypto');
const { log } = require('./observability/logger');
const { AppError } = require('./observability/errors');
const { authRouter } = require('./modules/auth/auth-controller');
const { companyRouter } = require('./modules/companies/company-controller');
const { appsRouter } = require('./modules/apps-catalog/apps-controller');
const { serversRouter } = require('./modules/servers/servers-controller');
const { customersRouter } = require('./modules/customers/customers-controller');
const { financeRouter } = require('./modules/finance/finance-controller');
const { whatsappRouter } = require('./modules/whatsapp/whatsapp-controller');
const { aiRouter } = require('./modules/ai/ai-controller');

function ensureSecurityEnv() {
  const key = process.env.APP_ENCRYPTION_KEY || '';
  if (key.length < 32) {
    throw new Error('APP_ENCRYPTION_KEY ausente ou inválida. Use no mínimo 32 caracteres.');
  }
  const webhookSecret = process.env.WEBHOOK_SHARED_SECRET || '';
  if (webhookSecret.length < 16) {
    throw new Error('WEBHOOK_SHARED_SECRET ausente ou inválida. Use no mínimo 16 caracteres.');
  }
}

ensureSecurityEnv();

const server = http.createServer(async (req, res) => {
  const requestId = req.headers['x-request-id'] || randomUUID();
  res.setHeader('x-request-id', requestId);
  try {
    if (req.url === '/health') {
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ ok: true, service: 'api', requestId }));
    }

    for (const router of [authRouter, companyRouter, appsRouter, serversRouter, customersRouter, financeRouter, whatsappRouter, aiRouter]) {
      const handled = await router(req, res);
      if (handled !== false) return;
    }

    log('info', 'rota_nao_encontrada', { path: req.url, requestId });
    res.writeHead(404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ erro: 'Não encontrado', requestId }));
  } catch (error) {
    const status = error instanceof AppError ? error.status : 500;
    log('error', 'erro_backend', { requestId, status, message: error.message });
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ erro: 'Não foi possível concluir a ação agora.', requestId }));
  }
});

server.listen(3001, () => log('info', 'api_iniciada', { porta: 3001 }));
