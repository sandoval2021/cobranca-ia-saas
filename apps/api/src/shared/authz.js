function getCtx(req) {
  const userId = req.headers['x-user-id'] || 'anon';
  const companyId = req.headers['x-company-id'] || null;
  const role = req.headers['x-role'] || 'owner';
  return { userId, companyId, role };
}
function ensureCompanyScope(ctx, companyId) {
  if (ctx.role === 'super_admin') return true;
  return ctx.companyId && ctx.companyId === companyId;
}
module.exports = { getCtx, ensureCompanyScope };
