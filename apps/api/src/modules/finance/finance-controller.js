const { getCtx } = require('../../shared/authz');
const svc = require('./finance-service');
async function parseBody(req){const c=[];for await(const x of req)c.push(x);return c.length?JSON.parse(Buffer.concat(c).toString('utf8')):{};}
async function financeRouter(req,res){const ctx=getCtx(req);
 if(req.method==='POST'&&req.url==='/financeiro/assinatura/iniciar-trial'){const r=await svc.startTrial(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/integracoes/mercado-pago/conectar'){const b=await parseBody(req);const r=await svc.connectMp(ctx,b);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url.match(/^\/clientes\/[^/]+\/cobrancas$/)){const customerId=req.url.split('/')[2];const b=await parseBody(req);const r=await svc.createCharge(ctx,{...b,customer_id:customerId});res.writeHead(201,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/webhooks/mercado-pago'){const b=await parseBody(req);const r=await svc.processWebhook(b,req.headers);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url.match(/^\/renovacoes\/tarefas\/[^/]+\/confirmar$/)){const taskId=req.url.split('/')[3];const r=await svc.confirmRenewal(ctx,taskId);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/financeiro/resumo-dono'){const r=svc.ownerSummary(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/admin/financeiro/resumo'){const r=svc.adminSummary(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 return false;}
module.exports={financeRouter};
