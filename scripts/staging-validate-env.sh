#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.staging}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERRO] Arquivo não encontrado: $ENV_FILE"
  exit 1
fi

required_vars=(
  STAGING_MODE
  NODE_ENV
  APP_ENCRYPTION_KEY
  WEBHOOK_SHARED_SECRET
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  ALLOW_REAL_PAYMENTS
  ALLOW_REAL_WHATSAPP
  ALLOW_REAL_AI
)

missing=0
for var in "${required_vars[@]}"; do
  if ! grep -E "^${var}=" "$ENV_FILE" >/dev/null; then
    echo "[ERRO] Variável ausente: $var"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

staging_mode="$(grep -E '^STAGING_MODE=' "$ENV_FILE" | tail -n1 | cut -d'=' -f2-)"
node_env="$(grep -E '^NODE_ENV=' "$ENV_FILE" | tail -n1 | cut -d'=' -f2-)"

if [[ "$staging_mode" != "true" ]]; then
  echo "[ERRO] STAGING_MODE deve ser true"
  exit 1
fi

if [[ "$node_env" == "production" ]]; then
  echo "[ERRO] NODE_ENV=production é proibido em staging"
  exit 1
fi

if grep -E '^MERCADO_PAGO_ACCESS_TOKEN=APP_USR-' "$ENV_FILE" >/dev/null && ! grep -E '^ALLOW_REAL_PAYMENTS=true' "$ENV_FILE" >/dev/null; then
  echo "[ALERTA] Token real de pagamento detectado sem ALLOW_REAL_PAYMENTS=true"
fi

if grep -E '^EVOLUTION_API_URL=.*api\.whatsapp\.com' "$ENV_FILE" >/dev/null && ! grep -E '^ALLOW_REAL_WHATSAPP=true' "$ENV_FILE" >/dev/null; then
  echo "[ALERTA] Endpoint WhatsApp real detectado sem ALLOW_REAL_WHATSAPP=true"
fi

echo "[OK] Validação de ambiente staging concluída com sucesso: $ENV_FILE"
