const { log } = require('../../observability/logger');

async function registerAuditEvent({ companyId, actorUserId, eventName, entityType, entityId, metadata }) {
  log('info', 'auditoria_evento', {
    companyId,
    actorUserId,
    eventName,
    entityType,
    entityId,
    metadata: metadata || {}
  });
}

async function registerSensitiveView({ companyId, actorUserId, entityType, entityId, reason }) {
  log('info', 'auditoria_visualizacao_sensivel', { companyId, actorUserId, entityType, entityId, reason });
}

module.exports = { registerAuditEvent, registerSensitiveView };
