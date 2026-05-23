# Staging: variáveis obrigatórias

> **Objetivo:** habilitar ambiente de staging seguro, sem dados reais e sem credenciais de produção.

## Regras de segurança
- Não reutilizar segredos de produção.
- Não commitar valores reais no repositório.
- Usar apenas chaves de staging/sandbox.

## Variáveis obrigatórias

| Variável | Obrigatória | Formato esperado | Observação |
|---|---|---|---|
| `APP_ENCRYPTION_KEY` | Sim | String longa/base64 | Chave exclusiva para staging. |
| `WEBHOOK_SHARED_SECRET` | Sim | String aleatória | Segredo compartilhado entre emissores e API de staging. |
| `OPENAI_API_KEY` | Sim | `sk-...` | Chave de projeto dedicada ao staging. |
| `EVOLUTION_API_URL` | Sim | URL HTTPS | Endpoint da Evolution para staging/sandbox. |
| `EVOLUTION_API_KEY` | Sim | String/token | Token da Evolution de staging. |
| `MERCADO_PAGO_CLIENT_ID` | Sim | String | Conta sandbox do Mercado Pago. |
| `MERCADO_PAGO_CLIENT_SECRET` | Sim | String | Segredo sandbox do Mercado Pago. |
| `RESEND_API_KEY` | Sim | `re_...` | Chave de ambiente de testes. |
| `SUPABASE_URL` | Sim | URL HTTPS | Projeto Supabase de staging. |
| `SUPABASE_SERVICE_ROLE_KEY` | Sim | JWT longa | Chave service_role do projeto staging. |

## Exemplo seguro (.env.staging)
```env
APP_ENCRYPTION_KEY=CHANGE_ME_STAGING_ONLY
WEBHOOK_SHARED_SECRET=CHANGE_ME_STAGING_ONLY
OPENAI_API_KEY=sk-staging-placeholder
EVOLUTION_API_URL=https://evolution-staging.example.com
EVOLUTION_API_KEY=staging-placeholder-token
MERCADO_PAGO_CLIENT_ID=staging_client_id
MERCADO_PAGO_CLIENT_SECRET=staging_client_secret
RESEND_API_KEY=re_staging_placeholder
SUPABASE_URL=https://staging-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=staging_service_role_key_placeholder
```
