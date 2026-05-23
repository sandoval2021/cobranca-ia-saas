#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.staging}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERRO] Arquivo não encontrado: $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

echo "[INFO] Iniciando API com variáveis de staging locais"
npm --workspace apps/api run dev
