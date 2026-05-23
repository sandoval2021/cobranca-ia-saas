#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.staging}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERRO] Arquivo não encontrado: $ENV_FILE"
  exit 1
fi

required_vars=(
  APP_ENCRYPTION_KEY
  WEBHOOK_SHARED_SECRET
  OPENAI_API_KEY
  EVOLUTION_API_URL
  EVOLUTION_API_KEY
  MERCADO_PAGO_CLIENT_ID
  MERCADO_PAGO_CLIENT_SECRET
  RESEND_API_KEY
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
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

echo "[OK] Todas as variáveis obrigatórias foram encontradas em $ENV_FILE"
