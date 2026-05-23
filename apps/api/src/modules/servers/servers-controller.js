const { db, id, now } = require('../../shared/store');
const { getCtx, ensureCompanyScope } = require('../../shared/authz');
async function parseBody(req){const c=[];for await(const x of req)c.push(x);return c.length?JSON.parse(Buffer.concat(c).toString('utf8')):{};}
async function serversRouter(req,res){const ctx=getCtx(req);
 if(req.method==='GET'&&req.url==='/servidores'){const items=db.servers.filter(s=>ensureCompanyScope(ctx,s.company_id)).map(s=>({...s,clientes_count:db.customers.filter(c=>c.primary_server_id===s.id).length}));res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(items));}
 if(req.method==='POST'&&req.url==='/servidores'){const b=await parseBody(req);const s={id:id(),company_id:ctx.companyId,name:b.name,color:b.color||'#777',status:b.status||'ativo',fixed_link:b.fixed_link||'',notes:b.notes||'',created_at:now()};db.servers.push(s);res.writeHead(201,{'content-type':'application/json'});return res.end(JSON.stringify(s));}
 if(req.method==='POST'&&req.url.startsWith('/servidores/')&&req.url.endsWith('/rotas')){const serverId=req.url.split('/')[2];const b=await parseBody(req);const r={id:id(),company_id:ctx.companyId,server_id:serverId,route_name:b.route_name,route_url:b.route_url,route_type:b.route_type||'principal',priority:b.priority||1,status:b.status||'ativa',last_checked_at:null,created_at:now()};db.routes.push(r);res.writeHead(201,{'content-type':'application/json'});return res.end(JSON.stringify(r));}
 return false;}
module.exports={serversRouter};
