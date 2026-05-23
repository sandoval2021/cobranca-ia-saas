#!/usr/bin/env bash
set -euo pipefail

MIGRATIONS_DIR="infra/supabase/migrations"

if [[ ! -d "$MIGRATIONS_DIR" ]]; then
  echo "[ERRO] Diretório de migrations não encontrado: $MIGRATIONS_DIR"
  exit 1
fi

count=$(find "$MIGRATIONS_DIR" -maxdepth 1 -name '*.sql' | wc -l | tr -d ' ')

if [[ "$count" -eq 0 ]]; then
  echo "[ERRO] Nenhuma migration SQL encontrada em $MIGRATIONS_DIR"
  exit 1
fi

echo "[OK] $count migrations detectadas em $MIGRATIONS_DIR"
echo "[INFO] Validação estrutural concluída (sem aplicar em produção)."
