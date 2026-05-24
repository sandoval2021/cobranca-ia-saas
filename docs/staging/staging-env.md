# Staging: variáveis obrigatórias (modo seguro)

## Obrigatórias
- `STAGING_MODE=true`
- `NODE_ENV=staging`
- `APP_ENCRYPTION_KEY`
- `WEBHOOK_SHARED_SECRET`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ALLOW_REAL_PAYMENTS=false`
- `ALLOW_REAL_WHATSAPP=false`
- `ALLOW_REAL_AI=false`

## Integrações (sempre sandbox por padrão)
- `MERCADO_PAGO_CLIENT_ID`
- `MERCADO_PAGO_CLIENT_SECRET`
- `EVOLUTION_API_URL`
- `EVOLUTION_API_KEY`
- `OPENAI_API_KEY`
- `RESEND_API_KEY`

## Regras
- Bloquear inicialização se `STAGING_MODE!=true`.
- Bloquear inicialização se `NODE_ENV=production`.
- Alertar quando houver credenciais potencialmente reais sem flags explícitas de liberação.
