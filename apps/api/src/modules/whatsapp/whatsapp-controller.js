const { getCtx } = require('../../shared/authz');
const svc = require('./whatsapp-service');
async function parseBody(req){const c=[];for await(const x of req)c.push(x);return c.length?JSON.parse(Buffer.concat(c).toString('utf8')):{};}
async function whatsappRouter(req,res){const ctx=getCtx(req);
 if(req.method==='POST'&&req.url==='/whatsapp/instancia/criar'){const b=await parseBody(req);const r=await svc.createInstance(ctx,b);res.writeHead(201,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/whatsapp/instancia/reconectar'){const r=await svc.reconnect(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/whatsapp/instancia/desconectar'){const r=await svc.disconnect(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/whatsapp/instancia/remover'){const r=await svc.removeInstance(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/whatsapp/instancia/status'){const r=await svc.status(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/whatsapp/instancia/qr'){const r=await svc.qr(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/whatsapp/mensagens/enviar-texto'){const b=await parseBody(req);const r=await svc.enqueueSend(ctx,{...b,kind:'texto'});res.writeHead(202,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/whatsapp/mensagens/enviar-template'){const b=await parseBody(req);const r=await svc.enqueueSend(ctx,{...b,kind:'template'});res.writeHead(202,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/whatsapp/fila/processar'){const r=await svc.processQueue(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/webhooks/evolution/mensagens'){const b=await parseBody(req);const r=await svc.receiveWebhook(b,req.headers);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/whatsapp/painel-dono'){const r=svc.ownerPanel(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/admin/whatsapp/painel'){const r=svc.adminPanel(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 return false;}
module.exports={whatsappRouter};
