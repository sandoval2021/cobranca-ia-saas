const { db, id, now } = require('../../shared/store');
const { getCtx } = require('../../shared/authz');
async function parseBody(req){const c=[];for await(const x of req)c.push(x);return c.length?JSON.parse(Buffer.concat(c).toString('utf8')):{};}
async function companyRouter(req,res){
 const ctx=getCtx(req);
 if(req.method==='POST'&&req.url==='/empresa'){const b=await parseBody(req);const c={id:id(),name:b.name||'Minha Empresa',lifecycle_status:b.lifecycle_status||'teste',created_at:now()};db.companies.push(c);res.writeHead(201,{'content-type':'application/json'});return res.end(JSON.stringify(c));}
 if(req.method==='GET'&&req.url==='/empresa/meu-perfil'){const c=db.companies.find(x=>x.id===ctx.companyId);res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(c||null));}
 if(req.method==='GET'&&req.url==='/admin/empresas'){if(ctx.role!=='super_admin'){res.writeHead(403);return res.end(JSON.stringify({erro:'Sem permissão'}));}res.writeHead(200,{'content-type':'application/json'});return res.end(JSON.stringify(db.companies));}
 return false;
}
module.exports={companyRouter};
