const { db, id, now } = require('../../shared/store');
const { AppError } = require('../../observability/errors');
const { registerAuditEvent } = require('../audit/audit-service');

if (!db.ai) db.ai = { settings: [], conversations: [], intents: [], messages: [], guards: [], handoff: [], loop: [], memory: [] };

function assertCompany(ctx){ if(!ctx.companyId) throw new AppError('Empresa inválida',403); }
function getSettings(ctx){ let s=db.ai.settings.find(x=>x.company_id===ctx.companyId); if(!s){ s={id:id(),company_id:ctx.companyId,enabled:false,model_primary:'gpt-4o-mini',model_fallback:'gpt-4o-mini',daily_token_limit:200000,monthly_token_limit:3000000,daily_cost_limit_cents:3000,monthly_cost_limit_cents:50000,consumed_daily_tokens:0,consumed_monthly_tokens:0,consumed_daily_cost_cents:0,consumed_monthly_cost_cents:0}; db.ai.settings.push(s);} return s; }
function getConversation(ctx, threadKey, customerId=null){ let c=db.ai.conversations.find(x=>x.company_id===ctx.companyId&&x.thread_key===threadKey); if(!c){ c={id:id(),company_id:ctx.companyId,customer_id:customerId,thread_key:threadKey,status:'ia_ativa',locked:false,lock_until:null,human_required:false,created_at:now(),updated_at:now()}; db.ai.conversations.push(c);} return c; }

function classifyIntent(text=''){ const t=text.toLowerCase(); if(/humano|atendente/.test(t)) return ['pedido_humano',0.95]; if(/paguei|pagamento|pix/.test(t)) return ['pagamento',0.9]; if(/renova|renovação/.test(t)) return ['renovacao',0.85]; if(/erro|não funciona|travou|suporte/.test(t)) return ['suporte',0.88]; if(/cobran|venc/.test(t)) return ['cobranca',0.82]; if(/cancel/.test(t)) return ['cancelamento',0.85]; return ['duvida_simples',0.7]; }

function guardFinancialClaims(text=''){ const t=text.toLowerCase(); if(/pagamento confirmado|já confirmou pagamento/.test(t)) return {blocked:true,action:'confirmar_pagamento',reason:'confirmacao_financeira_proibida'}; if(/renovação confirmada|já renovei/.test(t)) return {blocked:true,action:'confirmar_renovacao',reason:'confirmacao_renovacao_proibida'}; if(/valor.*\d/.test(t) && /definir|mudar/.test(t)) return {blocked:true,action:'alterar_valor',reason:'alteracao_financeira_proibida'}; return {blocked:false}; }

function dedupKey(ctx, conv, text){ return `${ctx.companyId}:${conv.id}:${(text||'').trim().toLowerCase().slice(0,80)}`; }

function checkLoop(ctx, conv, text){ const key=dedupKey(ctx,conv,text); const rec=db.ai.loop.find(x=>x.company_id===ctx.companyId&&x.dedup_key===key); const nowTs=Date.now(); if(rec && (!rec.cooldown_until || nowTs<Date.parse(rec.cooldown_until))){ rec.hit_count += 1; rec.updated_at=now(); if(rec.hit_count>=3){ rec.cooldown_until=new Date(nowTs+120000).toISOString(); return {blocked:true,reason:'anti_loop'}; } return {blocked:true,reason:'duplicada'}; } db.ai.loop.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,dedup_key:key,window_seconds:120,hit_count:1,cooldown_until:new Date(nowTs+120000).toISOString(),created_at:now(),updated_at:now()}); return {blocked:false}; }

function consumeCost(settings, model, inTok, outTok){ const used=inTok+outTok; const cost=Math.ceil(used*0.02); settings.consumed_daily_tokens += used; settings.consumed_monthly_tokens += used; settings.consumed_daily_cost_cents += cost; settings.consumed_monthly_cost_cents += cost; const over=settings.consumed_daily_cost_cents>settings.daily_cost_limit_cents || settings.consumed_monthly_cost_cents>settings.monthly_cost_limit_cents || settings.consumed_daily_tokens>settings.daily_token_limit || settings.consumed_monthly_tokens>settings.monthly_token_limit; return {used,cost,over}; }

function chooseModel(settings, intent){ if(['duvida_simples','cobranca'].includes(intent)) return settings.model_fallback || settings.model_primary; if(settings.consumed_daily_cost_cents > settings.daily_cost_limit_cents*0.8) return settings.model_fallback || settings.model_primary; return settings.model_primary; }

async function configure(ctx, input){ assertCompany(ctx); const s=getSettings(ctx); Object.assign(s,input); s.updated_at=now(); return s; }

async function processMessage(ctx, input){
  assertCompany(ctx);
  const s=getSettings(ctx);
  if(!s.enabled) throw new AppError('IA desativada para esta empresa',409);
  const conv=getConversation(ctx,input.thread_key||input.customer_phone||id(),input.customer_id||null);
  if(conv.locked && conv.lock_until && Date.now()<Date.parse(conv.lock_until)) throw new AppError('Conversa em processamento. Tente novamente.',429);
  conv.locked=true; conv.lock_until=new Date(Date.now()+15000).toISOString();
  try {
    if(input.direction==='saida') return {ignored:true,reason:'nao_responder_mensagem_propria'};
    const loop=checkLoop(ctx,conv,input.text||'');
    if(loop.blocked) return {ignored:true,reason:loop.reason};

    const [intent,confidence]=classifyIntent(input.text||'');
    db.ai.intents.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,intent,confidence,metadata:{origin:'classificador'},created_at:now()});

    if(intent==='pedido_humano'){ conv.status='precisa_humano'; conv.human_required=true; db.ai.handoff.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,status:'precisa_humano',reason:'pedido_cliente',created_at:now(),updated_at:now()}); return {handoff:true,status:'precisa_humano'}; }

    const guard=guardFinancialClaims(input.text||'');
    if(guard.blocked){ db.ai.guards.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,event_name:'guardrail_block',blocked_action:guard.action,reason:guard.reason,metadata:{text:input.text},created_at:now()}); return {blocked:true,reason:guard.reason}; }

    const model=chooseModel(s,intent);
    const response = intent==='suporte' ? 'Para te ajudar melhor, envie foto da tela ou descreva o erro.' : intent==='cobranca' ? 'Olá! Vi aqui seu vencimento. Posso te ajudar com a regularização?' : 'Entendi! Vou te ajudar com isso agora.';
    const usage=consumeCost(s,model,120,80);
    if(usage.over){ conv.status='precisa_humano'; conv.human_required=true; return {handoff:true,status:'precisa_humano',reason:'limite_custo'}; }

    db.ai.messages.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,direction:'saida',prompt:input.text||'',response,model_used:model,tokens_input:120,tokens_output:80,cost_cents:usage.cost,latency_ms:300,origin:'orquestrador',created_at:now()});
    db.ai.memory.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,summary:`Intent ${intent} tratada`,facts:{intent},created_at:now()});
    await registerAuditEvent({companyId:ctx.companyId,actorUserId:ctx.userId,eventName:'ia_resposta_gerada',entityType:'ai_conversation',entityId:conv.id});
    return {reply:response,intent,model,cost_cents:usage.cost};
  } finally {
    conv.locked=false; conv.lock_until=null; conv.updated_at=now();
  }
}

async function handoffAction(ctx, conversationId, action){ assertCompany(ctx); const conv=db.ai.conversations.find(c=>c.id===conversationId&&c.company_id===ctx.companyId); if(!conv) throw new AppError('Conversa não encontrada',404); if(action==='abrir'){ conv.status='precisa_humano'; conv.human_required=true; if(!db.ai.handoff.find(h=>h.company_id===ctx.companyId&&h.conversation_id===conv.id)) db.ai.handoff.push({id:id(),company_id:ctx.companyId,conversation_id:conv.id,status:'precisa_humano',reason:'manual',created_at:now(),updated_at:now()}); }
 if(action==='assumir'){ const h=db.ai.handoff.find(h=>h.company_id===ctx.companyId&&h.conversation_id===conv.id); if(h){h.status='em_atendimento';h.assigned_user_id=ctx.userId;h.updated_at=now();} conv.status='humano_assumiu'; }
 if(action==='retomar'){ const h=db.ai.handoff.find(h=>h.company_id===ctx.companyId&&h.conversation_id===conv.id); if(h){h.status='retomado_ia';h.updated_at=now();} conv.status='ia_ativa'; conv.human_required=false; }
 return conv; }

function ownerPanel(ctx){ assertCompany(ctx); const s=getSettings(ctx); const msgs=db.ai.messages.filter(m=>m.company_id===ctx.companyId); const hand=db.ai.handoff.filter(h=>h.company_id===ctx.companyId); return {ia_ativa:s.enabled,consumo_tokens_dia:s.consumed_daily_tokens,custo_dia_cents:s.consumed_daily_cost_cents,respostas:msgs.length,transferencias_humano:hand.length,falhas_guardrail:db.ai.guards.filter(g=>g.company_id===ctx.companyId).length}; }
function adminPanel(ctx){ if(ctx.role!=='super_admin') throw new AppError('Sem permissão',403); const byCompany={}; for(const s of db.ai.settings){ byCompany[s.company_id]=s.consumed_monthly_cost_cents; } const top=Object.entries(byCompany).sort((a,b)=>b[1]-a[1]).slice(0,5).map(([company_id,cost])=>({company_id,cost})); return {uso_total_tokens:db.ai.settings.reduce((a,s)=>a+s.consumed_monthly_tokens,0),empresas_maior_consumo:top,erros_guardrail:db.ai.guards.length,bloqueadas_limite:db.ai.settings.filter(s=>s.consumed_monthly_cost_cents>s.monthly_cost_limit_cents).length}; }

module.exports={configure,processMessage,handoffAction,ownerPanel,adminPanel};
