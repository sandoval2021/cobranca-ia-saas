const { registerOwner, confirmEmailCode, requestPasswordReset } = require('./auth-service');

async function parseBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

async function authRouter(req, res) {
  if (req.method === 'POST' && req.url === '/auth/cadastro') {
    const body = await parseBody(req);
    const data = await registerOwner(body);
    res.writeHead(201, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(data));
  }
  if (req.method === 'POST' && req.url === '/auth/confirmar-email') {
    const body = await parseBody(req);
    const data = await confirmEmailCode(body);
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(data));
  }
  if (req.method === 'POST' && req.url === '/auth/esqueci-senha') {
    const body = await parseBody(req);
    const data = await requestPasswordReset(body);
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(data));
  }
  return false;
}

module.exports = { authRouter };
