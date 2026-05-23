const crypto = require('crypto');
const { db, id, now } = require('../../shared/store');
const { encryptText } = require('../../shared/crypto');
const { AppError } = require('../../observability/errors');
const { registerAuditEvent } = require('../audit/audit-service');

if (!db.finance) {
  db.finance = {
    subscriptions: [], mpConnections: [], charges: [], txs: [], webhookEvents: [], feeLedger: [], renewalTasks: [], finAudit: []
  };
}

function assertCompany(ctx) { if (!ctx.companyId) throw new AppError('Empresa inválida', 403); }
function calcFee(amountCents) { return Math.round(amountCents * 0.01); }
function extRef(companyId, customerId) { return `${companyId}:${customerId}:${Date.now()}`; }

async function startTrial(ctx) {
  assertCompany(ctx);
  const exists = db.finance.subscriptions.find(s => s.company_id === ctx.companyId);
  if (exists) return exists;
  const sub = { id:id(), company_id:ctx.companyId, status:'trial', trial_started_at:now(), trial_ends_at:new Date(Date.now()+7*86400000).toISOString(), monthly_amount_cents:3000, partial_blocked:false };
  db.finance.subscriptions.push(sub);
  return sub;
}

async function connectMp(ctx, input) {
  assertCompany(ctx);
  const accessToken = input.access_token || '';
  const refreshToken = input.refresh_token || '';
  const conn = { id:id(), company_id:ctx.companyId, status:'connected', mp_user_id:input.mp_user_id || null, access_token_enc:encryptText(accessToken), refresh_token_enc:encryptText(refreshToken), connected_at:now() };
  db.finance.mpConnections = db.finance.mpConnections.filter(c => c.company_id !== ctx.companyId);
  db.finance.mpConnections.push(conn);
  await registerAuditEvent({ companyId:ctx.companyId, actorUserId:ctx.userId, eventName:'mp_conectado' });
  return { status:'connected' };
}

async function createCharge(ctx, input) {
  assertCompany(ctx);
  const amount = Number(input.amount_cents || 0);
  if (amount <= 0) throw new AppError('Valor inválido', 422);
  const platformFee = calcFee(amount);
  const estimatedNet = amount - platformFee;
  const reference = extRef(ctx.companyId, input.customer_id);
  const dup = db.finance.charges.find(c => c.company_id===ctx.companyId && c.external_reference===reference);
  if (dup) throw new AppError('Cobrança duplicada', 409);
  const charge = { id:id(), company_id:ctx.companyId, customer_id:input.customer_id, external_reference:reference, payment_link:`https://pagamento.exemplo/${reference}`, amount_cents:amount, platform_fee_cents:platformFee, provider_fee_cents:0, estimated_net_cents:estimatedNet, status:'pendente', created_at:now() };
  db.finance.charges.push(charge);
  db.finance.feeLedger.push({ id:id(), company_id:ctx.companyId, charge_id:charge.id, fee_percent:1.0, fee_cents:platformFee, base_amount_cents:amount, created_at:now() });
  await registerAuditEvent({ companyId:ctx.companyId, actorUserId:ctx.userId, eventName:'cobranca_criada', entityType:'charge', entityId:charge.id });
  return { ...charge, aviso_taxa: 'Taxas do Mercado Pago podem ser aplicadas separadamente.' };
}

function validateWebhookSignature(sig) { return Boolean(sig && sig.length >= 10); }

async function processWebhook(input, headers) {
  const shared = process.env.WEBHOOK_SHARED_SECRET || '';
  if (!shared) throw new AppError('Confirmação automática indisponível', 503);
  const provided = String(headers['x-webhook-secret'] || '');
  if (provided !== shared) throw new AppError('Assinatura inválida', 401);
  const charge = db.finance.charges.find(c => c.id === input.charge_id);
  if (!charge) throw new AppError('Cobrança não encontrada', 404);
  const companyId = charge.company_id;
  const actorUserId = 'webhook';
  const eventId = String(input.provider_event_id || '');
  if (!eventId) throw new AppError('Evento inválido', 422);
  const exists = db.finance.webhookEvents.find(e => e.company_id===companyId && e.provider_event_id===eventId);
  if (exists) return { ok:true, duplicated:true };
  const signatureValid = validateWebhookSignature(headers['x-signature']);
  if (!signatureValid) throw new AppError('Assinatura inválida', 401);
  db.finance.webhookEvents.push({ id:id(), company_id:companyId, provider_event_id:eventId, signature_valid:true, processed:false, payload:input, created_at:now() });

  const txDup = db.finance.txs.find(t => t.company_id===companyId && t.provider_payment_id===String(input.provider_payment_id));
  if (txDup) return { ok:true, duplicated:true };

  db.finance.txs.push({ id:id(), company_id:companyId, charge_id:charge.id, provider_payment_id:String(input.provider_payment_id), provider_status:String(input.provider_status||'approved'), paid_amount_cents:input.paid_amount_cents||charge.amount_cents, provider_fee_cents:input.provider_fee_cents||0, created_at:now() });

  if (charge.status !== 'aprovado') {
    charge.status = 'aprovado';
    const taskExists = db.finance.renewalTasks.find(t => t.company_id===companyId && t.charge_id===charge.id);
    if (!taskExists) db.finance.renewalTasks.push({ id:id(), company_id:companyId, charge_id:charge.id, customer_id:charge.customer_id, status:'pendente', created_at:now() });
  }
  await registerAuditEvent({ companyId, actorUserId, eventName:'pagamento_confirmado', entityType:'charge', entityId:charge.id });
  return { ok:true, duplicated:false };
}

async function confirmRenewal(ctx, taskId) {
  assertCompany(ctx);
  const task = db.finance.renewalTasks.find(t => t.id===taskId && t.company_id===ctx.companyId);
  if (!task) throw new AppError('Tarefa não encontrada', 404);
  if (task.status === 'concluida') throw new AppError('Renovação já confirmada', 409);
  task.status='concluida'; task.confirmed_by_user_id=ctx.userId; task.confirmed_at=now();
  await registerAuditEvent({ companyId:ctx.companyId, actorUserId:ctx.userId, eventName:'renovacao_confirmada', entityType:'renewal_task', entityId:task.id });
  return task;
}

function ownerSummary(ctx){
  assertCompany(ctx);
  const charges=db.finance.charges.filter(c=>c.company_id===ctx.companyId);
  const recebidos=charges.filter(c=>c.status==='aprovado').length;
  const pendentes=charges.filter(c=>c.status==='pendente').length;
  const taxas=charges.reduce((a,c)=>a+c.platform_fee_cents,0);
  const volume=charges.reduce((a,c)=>a+c.amount_cents,0);
  return { recebidos, pendentes, volume_cents:volume, taxas_plataforma_cents:taxas };
}

function adminSummary(ctx){
  if(ctx.role!=='super_admin') throw new AppError('Sem permissão',403);
  const charges=db.finance.charges;
  return { receita_taxa_cents:charges.reduce((a,c)=>a+c.platform_fee_cents,0), volume_total_cents:charges.reduce((a,c)=>a+c.amount_cents,0), pagamentos_falhos:charges.filter(c=>c.status==='falhou').length };
}

module.exports={startTrial,connectMp,createCharge,processWebhook,confirmRenewal,ownerSummary,adminSummary};
