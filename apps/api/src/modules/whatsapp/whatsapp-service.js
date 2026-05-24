const { db, id, now } = require('../../shared/store');
const { encryptText } = require('../../shared/crypto');
const { AppError } = require('../../observability/errors');
const { registerAuditEvent } = require('../audit/audit-service');
const { assertRealWhatsappAllowed } = require('../../shared/staging-guards');

if (!db.wa) db.wa = { instances: [], events: [], dedup: [], queue: [], messages: [], webhook: [] };

function assertCompany(ctx){ if(!ctx.companyId) throw new AppError('Empresa inválida',403); }
function dedupKey({companyId, customerId, kind, ref, window='1h'}){ return `${companyId}:${customerId||'na'}:${kind}:${ref}:${window}`; }
function addEvent(companyId, waInstanceId, event, metadata={}){ db.wa.events.push({id:id(),company_id:companyId,wa_instance_id:waInstanceId,event_name:event,metadata,created_at:now()}); }

function getInstance(ctx){ return db.wa.instances.find(i=>i.company_id===ctx.companyId); }

async function createInstance(ctx, input){
  assertCompany(ctx);
  if(getInstance(ctx)) throw new AppError('Empresa já possui WhatsApp principal',409);
  const inst={id:id(),company_id:ctx.companyId,instance_name:input.instance_name||`empresa_${ctx.companyId.slice(0,8)}`,status:'desconectado',is_connected:false,last_connected_at:null,qr_code:'QR-PENDENTE',fail_count:0,blocked:false,daily_limit:input.daily_limit||300,sent_today:0,cooldown_until:null,token_enc:encryptText(input.token||''),created_at:now(),updated_at:now()};
  db.wa.instances.push(inst); addEvent(ctx.companyId,inst.id,'instancia_criada');
  return { id:inst.id,status:inst.status,instance_name:inst.instance_name };
}
async function reconnect(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404); i.status='desconectado'; i.is_connected=false; i.qr_code='QR-ATUALIZADO'; i.updated_at=now(); addEvent(ctx.companyId,i.id,'reconectar_solicitado'); return {status:i.status,qr_code:i.qr_code}; }
async function disconnect(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404); i.status='desconectado'; i.is_connected=false; i.updated_at=now(); addEvent(ctx.companyId,i.id,'desconectado'); autoPauseByStatus(i); return {status:i.status}; }
async function removeInstance(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404); db.wa.instances=db.wa.instances.filter(x=>x.company_id!==ctx.companyId); addEvent(ctx.companyId,i.id,'instancia_removida'); return {removed:true}; }
async function status(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) return null; return {status:i.status,is_connected:i.is_connected,last_connected_at:i.last_connected_at,blocked:i.blocked,sent_today:i.sent_today,daily_limit:i.daily_limit}; }
async function qr(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404); return {qr_code:i.qr_code,status:i.status}; }

function autoPauseByStatus(i){ if(!i.is_connected || i.status==='desconectado' || i.fail_count>=5){ i.status='pausado'; i.blocked=true; i.cooldown_until=new Date(Date.now()+15*60000).toISOString(); }}
function canSend(i){ if(!i) return {ok:false,reason:'sem_instancia'}; if(i.blocked) return {ok:false,reason:'pausado'}; if(!i.is_connected) return {ok:false,reason:'desconectado'}; if(i.sent_today>=i.daily_limit) return {ok:false,reason:'limite_diario'}; if(i.cooldown_until && Date.now()<Date.parse(i.cooldown_until)) return {ok:false,reason:'cooldown'}; return {ok:true}; }

function registerDedup(companyId,key){ const exists=db.wa.dedup.find(d=>d.company_id===companyId && d.dedup_key===key && Date.now()<Date.parse(d.expires_at)); if(exists) return false; db.wa.dedup.push({id:id(),company_id:companyId,dedup_key:key,expires_at:new Date(Date.now()+3600*1000).toISOString(),created_at:now()}); return true; }

async function enqueueSend(ctx, input){
  assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404);
  const ref = input.reference || input.customer_id || input.to;
  const key = dedupKey({companyId:ctx.companyId,customerId:input.customer_id,kind:input.kind||'texto',ref,window:'1h'});
  if(!registerDedup(ctx.companyId,key)) return {queued:false,duplicated:true};
  const q={id:id(),company_id:ctx.companyId,customer_id:input.customer_id||null,wa_instance_id:i.id,dedup_key:key,msg_type:input.kind||'texto',payload:{to:input.to,text:input.text,template:input.template},priority:input.priority||5,status:'pendente',attempts:0,max_attempts:4,next_retry_at:null,last_error:null,created_at:now(),updated_at:now()};
  db.wa.queue.push(q); addEvent(ctx.companyId,i.id,'fila_enfileirada',{queue_id:q.id});
  return {queued:true,queue_id:q.id,dedup_key:key};
}

function retryAt(attempt){ const seq=[0,30,120,600]; return new Date(Date.now()+seq[Math.min(attempt,3)]*1000).toISOString(); }

async function processQueue(ctx){
  assertRealWhatsappAllowed();
  assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404);
  const allowed=canSend(i); if(!allowed.ok){ autoPauseByStatus(i); return {processed:0,paused:true,reason:allowed.reason}; }
  let processed=0;
  const items=db.wa.queue.filter(x=>x.company_id===ctx.companyId && ['pendente','falha_retry'].includes(x.status)).sort((a,b)=>a.priority-b.priority).slice(0,20);
  for(const q of items){
    if(q.next_retry_at && Date.now()<Date.parse(q.next_retry_at)) continue;
    q.status='enviando'; q.attempts+=1;
    const ok = Boolean(q.payload.to && (q.payload.text || q.payload.template));
    if(ok){
      q.status='enviado'; i.sent_today +=1;
      db.wa.messages.push({id:id(),company_id:ctx.companyId,customer_id:q.customer_id,wa_instance_id:i.id,queue_id:q.id,provider_message_id:`msg_${q.id}`,direction:'saida',msg_type:q.msg_type,content:q.payload.text||q.payload.template||'',status:'enviado',sent_at:now(),created_at:now()});
      processed +=1;
    } else {
      i.fail_count +=1; q.last_error='payload_invalido';
      if(q.attempts>=q.max_attempts){ q.status='falha_final'; } else { q.status='falha_retry'; q.next_retry_at=retryAt(q.attempts); }
      autoPauseByStatus(i);
    }
  }
  return {processed,paused:i.blocked,status:i.status};
}

async function receiveWebhook(input,headers){
  assertRealWhatsappAllowed();
  const shared = process.env.WEBHOOK_SHARED_SECRET || '';
  if (!shared) throw new AppError('Webhook indisponível', 503);
  const provided = String(headers['x-webhook-secret'] || '');
  if (provided !== shared) throw new AppError('Assinatura inválida', 401);
  const instanceName = String(input.instance_name || '');
  const i = db.wa.instances.find(x => x.instance_name === instanceName);
  if (!i) throw new AppError('Instância não encontrada',404);
  const companyId = i.company_id;
  const eventId=String(input.provider_event_id||'');
  if(!eventId) throw new AppError('Evento inválido',422);
  const sig=headers['x-signature']; if(!sig || String(sig).length<10) throw new AppError('Assinatura inválida',401);
  const dup=db.wa.webhook.find(e=>e.company_id===companyId&&e.provider_event_id===eventId); if(dup) return {ok:true,duplicated:true};
  db.wa.webhook.push({id:id(),company_id:companyId,provider_event_id:eventId,event_type:input.event_type||'message',payload:input,signature_valid:true,processed:false,created_at:now()});
  db.wa.messages.push({id:id(),company_id:companyId,customer_id:input.customer_id||null,wa_instance_id:i.id,provider_message_id:input.provider_message_id||`in_${eventId}`,direction:'entrada',msg_type:input.msg_type||'texto',content:input.text||'',media_url:input.media_url||null,status:'recebida',received_at:now(),created_at:now()});
  return {ok:true,duplicated:false};
}


async function pauseQueue(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404); i.blocked=true; i.status='pausado'; i.updated_at=now(); return {paused:true,status:i.status}; }
async function resumeQueue(ctx){ assertCompany(ctx); const i=getInstance(ctx); if(!i) throw new AppError('Instância não encontrada',404); i.blocked=false; if(i.status==='pausado') i.status='desconectado'; i.updated_at=now(); return {paused:false,status:i.status}; }
function queueSnapshot(ctx){ assertCompany(ctx); const i=getInstance(ctx); const items=db.wa.queue.filter(q=>q.company_id===ctx.companyId); return {pendente:items.filter(x=>x.status==='pendente').length,enviando:items.filter(x=>x.status==='enviando').length,falhou:items.filter(x=>x.status==='falha_final').length,retries:items.filter(x=>x.status==='falha_retry').length,pausada:Boolean(i?.blocked)}; }
function operationalHistory(ctx){ assertCompany(ctx); const queue=db.wa.queue.filter(q=>q.company_id===ctx.companyId).slice(-20).reverse(); const mapped=queue.map(q=>({tipo:q.msg_type,status:q.status,retries:q.attempts||0,data:q.updated_at||q.created_at,descricao:q.last_error||'Processado na fila'})); return {items:mapped,last_connection:getInstance(ctx)?.last_connected_at||null,last_failures:mapped.filter(x=>x.status==='falha_final').slice(0,5)}; }

function ownerPanel(ctx){ assertCompany(ctx); const i=getInstance(ctx); const msgs=db.wa.messages.filter(m=>m.company_id===ctx.companyId); const q=db.wa.queue.filter(m=>m.company_id===ctx.companyId && ['pendente','falha_retry'].includes(m.status)); return {instancia:i?{status:i.status,connected:i.is_connected,qr_code:i.qr_code}:null,mensagens_total:msgs.length,fila:q.length,falhas:db.wa.queue.filter(m=>m.company_id===ctx.companyId&&m.status==='falha_final').length}; }
function adminPanel(ctx){ if(ctx.role!=='super_admin') throw new AppError('Sem permissão',403); const instances=db.wa.instances; const connected=instances.filter(i=>i.is_connected).length; const disconnected=instances.filter(i=>!i.is_connected).length; const paused=instances.filter(i=>i.status==='pausado').length; const totalMsgs=db.wa.messages.length; const spamRisk=instances.filter(i=>i.sent_today>i.daily_limit*0.9).length; const excessiveFailures=instances.filter(i=>i.fail_count>=5).length; const stuckQueues=instances.filter(i=>db.wa.queue.some(q=>q.wa_instance_id===i.id && q.status==='pendente' && (Date.now()-Date.parse(q.created_at))>30*60000)).length; return {connected,disconnected,paused,total_msgs:totalMsgs,spam_risk_companies:spamRisk,excessive_failures:excessiveFailures,stuck_queues:stuckQueues}; }

module.exports={createInstance,reconnect,disconnect,removeInstance,status,qr,enqueueSend,processQueue,pauseQueue,resumeQueue,queueSnapshot,operationalHistory,receiveWebhook,ownerPanel,adminPanel};
