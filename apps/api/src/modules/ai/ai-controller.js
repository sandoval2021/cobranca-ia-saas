const { getCtx } = require('../../shared/authz');
const ai = require('./ai-service');
async function parseBody(req){const c=[];for await(const x of req)c.push(x);return c.length?JSON.parse(Buffer.concat(c).toString('utf8')):{};}
async function aiRouter(req,res){const ctx=getCtx(req);
 if(req.method==='GET'&&req.url==='/ia/configuracao'){const r=await ai.configure(ctx,{});res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='PATCH'&&req.url==='/ia/configuracao'){const b=await parseBody(req);const r=await ai.configure(ctx,b);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url==='/ia/processar-mensagem'){const b=await parseBody(req);const r=await ai.processMessage(ctx,b);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='POST'&&req.url.match(/^\/ia\/handoff\/[^/]+\/(abrir|assumir|retomar-ia)$/)){const parts=req.url.split('/');const cid=parts[3];const action=parts[4]==='retomar-ia'?'retomar':parts[4];const r=await ai.handoffAction(ctx,cid,action);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/ia/painel-dono'){const r=ai.ownerPanel(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 if(req.method==='GET'&&req.url==='/admin/ia/painel'){const r=ai.adminPanel(ctx);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 return false;}
module.exports={aiRouter};
