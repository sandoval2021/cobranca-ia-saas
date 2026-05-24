const { AppError } = require('../observability/errors');

function isTruthy(value) {
  return String(value || '').toLowerCase() === 'true';
}

function assertStagingEnvironment() {
  if (!isTruthy(process.env.STAGING_MODE)) {
    throw new Error('STAGING_MODE=true é obrigatório para iniciar o ambiente de staging.');
  }
  if (String(process.env.NODE_ENV || '').toLowerCase() === 'production') {
    throw new Error('NODE_ENV=production é proibido em staging seguro.');
  }

  const required = [
    'APP_ENCRYPTION_KEY',
    'WEBHOOK_SHARED_SECRET',
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY'
  ];

  const missing = required.filter((name) => !String(process.env[name] || '').trim());
  if (missing.length) {
    throw new Error(`Variáveis críticas ausentes: ${missing.join(', ')}`);
  }

  const allowRealPayments = isTruthy(process.env.ALLOW_REAL_PAYMENTS);
  const allowRealWhatsapp = isTruthy(process.env.ALLOW_REAL_WHATSAPP);
  const allowRealAI = isTruthy(process.env.ALLOW_REAL_AI);

  const suspicious = [];
  if ((process.env.MERCADO_PAGO_ACCESS_TOKEN || '').startsWith('APP_USR-') && !allowRealPayments) {
    suspicious.push('MERCADO_PAGO_ACCESS_TOKEN');
  }
  if ((process.env.EVOLUTION_API_URL || '').includes('api.whatsapp.com') && !allowRealWhatsapp) {
    suspicious.push('EVOLUTION_API_URL');
  }
  if ((process.env.OPENAI_API_KEY || '').startsWith('sk-') && !allowRealAI) {
    suspicious.push('OPENAI_API_KEY');
  }

  return {
    allowRealPayments,
    allowRealWhatsapp,
    allowRealAI,
    suspiciousCredentials: suspicious
  };
}

function assertRealPaymentsAllowed() {
  if (!isTruthy(process.env.ALLOW_REAL_PAYMENTS)) {
    throw new AppError('Pagamento real bloqueado em staging. Defina ALLOW_REAL_PAYMENTS=true explicitamente.', 403);
  }
}

function assertRealWhatsappAllowed() {
  if (!isTruthy(process.env.ALLOW_REAL_WHATSAPP)) {
    throw new AppError('Envio real de WhatsApp bloqueado em staging. Defina ALLOW_REAL_WHATSAPP=true explicitamente.', 403);
  }
}

function assertRealAIAllowed() {
  if (!isTruthy(process.env.ALLOW_REAL_AI)) {
    throw new AppError('IA livre bloqueada em staging. Defina ALLOW_REAL_AI=true explicitamente.', 403);
  }
}

module.exports = {
  assertStagingEnvironment,
  assertRealPaymentsAllowed,
  assertRealWhatsappAllowed,
  assertRealAIAllowed
};
