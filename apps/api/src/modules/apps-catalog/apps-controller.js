const { db, id, now } = require('../../shared/store');
const { getCtx, ensureCompanyScope } = require('../../shared/authz');
async function parseBody(req){const c=[];for await(const x of req)c.push(x);return c.length?JSON.parse(Buffer.concat(c).toString('utf8')):{};}
async function appsRouter(req,res){const ctx=getCtx(req);
 if(req.method==='GET'&&req.url==='/aplicativos'){const items=db.apps.filter(a=>ensureCompanyScope(ctx,a.company_id));res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(items));}
 if(req.method==='POST'&&req.url==='/aplicativos'){const b=await parseBody(req);const app={id:id(),company_id:ctx.companyId,name:b.name,color:b.color||'#999',requires_mac:!!b.requires_mac,requires_key:!!b.requires_key,requires_username:!!b.requires_username,requires_password:!!b.requires_password,requires_link:!!b.requires_link,support_message:b.support_message||'',created_at:now()};db.apps.push(app);res.writeHead(201,{'content-type':'application/json'});return res.end(JSON.stringify(app));}
 return false;}
module.exports={appsRouter};
