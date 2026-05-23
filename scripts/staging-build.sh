#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Executando build do monorepo em modo staging-safe"
npm run build

echo "[OK] Build finalizado"
