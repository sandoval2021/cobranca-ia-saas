const crypto = require('crypto');
const { AppError } = require('../../observability/errors');
const { registerAuditEvent } = require('../audit/audit-service');

const attempts = new Map();
const MAX_ATTEMPTS = 5;
const WINDOW_MS = 15 * 60 * 1000;

function now() {
  return Date.now();
}

function keyAttempt(prefix, value) {
  return `${prefix}:${String(value || '').toLowerCase()}`;
}

function hitAttempt(prefix, value) {
  const key = keyAttempt(prefix, value);
  const current = attempts.get(key);
  const t = now();
  if (!current || t > current.resetAt) {
    attempts.set(key, { count: 1, resetAt: t + WINDOW_MS });
    return 1;
  }
  current.count += 1;
  attempts.set(key, current);
  return current.count;
}

function ensureAttemptsBelowLimit(prefix, value) {
  const key = keyAttempt(prefix, value);
  const current = attempts.get(key);
  if (current && now() <= current.resetAt && current.count >= MAX_ATTEMPTS) {
    throw new AppError('Muitas tentativas. Tente novamente mais tarde.', 429, 'muitas_tentativas');
  }
}

function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

async function registerOwner(input) {
  const { email, whatsapp, password, confirmPassword } = input;
  if (!email || !whatsapp || !password || !confirmPassword) throw new AppError('Preencha todos os campos obrigatórios', 422);
  if (password !== confirmPassword) throw new AppError('As senhas não conferem', 422);
  if (password.length < 8) throw new AppError('Use uma senha mais forte', 422);

  const verificationCode = generateCode();
  const verificationCodeHash = hashCode(verificationCode);

  await registerAuditEvent({ eventName: 'cadastro_dono_iniciado', metadata: { email, whatsapp } });

  return {
    email,
    whatsapp,
    verificationCodeHash,
    expiresInMinutes: 15,
    blockedUntilEmailConfirmation: true
  };
}

async function confirmEmailCode({ expectedHash, typedCode, email }) {
  ensureAttemptsBelowLimit('confirm_email', email || expectedHash);
  if (!expectedHash || !typedCode) {
    hitAttempt('confirm_email', email || expectedHash);
    throw new AppError('Código inválido', 422);
  }
  if (hashCode(typedCode) !== expectedHash) {
    hitAttempt('confirm_email', email || expectedHash);
    throw new AppError('Código inválido', 422);
  }
  await registerAuditEvent({ eventName: 'email_confirmado', metadata: { email } });
  return { emailConfirmed: true };
}

async function requestPasswordReset({ email }) {
  if (!email) throw new AppError('Informe o e-mail', 422);
  ensureAttemptsBelowLimit('reset', email);
  const resetCode = generateCode();
  const resetCodeHash = hashCode(resetCode);
  await registerAuditEvent({ eventName: 'recuperacao_senha_solicitada', metadata: { email } });
  return { resetCodeHash, expiresInMinutes: 15 };
}

module.exports = { registerOwner, confirmEmailCode, requestPasswordReset };
