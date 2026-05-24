# Runbook de execução do staging (modo seguro)

> Escopo: subir **somente staging** com dados demo, sem integrações reais.

## 1) Configurar envs no ambiente
1. Copie o template para `.env.staging`.
2. Defina obrigatoriamente:
   - `STAGING_MODE=true`
   - `NODE_ENV=staging` (nunca `production`)
   - `ALLOW_REAL_PAYMENTS=false`
   - `ALLOW_REAL_WHATSAPP=false`
   - `ALLOW_REAL_AI=false`
3. Preencha apenas credenciais de sandbox/demo.
4. Valide:
   ```bash
   ./scripts/staging-validate-env.sh .env.staging
   ```

## 2) Rodar migrations (opção preferencial: Supabase CLI)
```bash
./scripts/staging-validate-migrations.sh

# autenticar (token pessoal; não versionar)
supabase login

# pegar PROJECT_REF de staging no dashboard Supabase:
# Project Settings -> General -> Reference ID
supabase link --project-ref <PROJECT_REF_STAGING>

# validação de segurança: confirmar projeto linkado é o de staging
cat supabase/config.toml | rg 'project_id|project_ref'

# aplicar migrations pendentes no projeto linkado
supabase db push
```

## 3) Aplicar seed demo (sem psql, via Supabase CLI)
```bash
# opção A: query única com arquivo local
supabase db query < infra/supabase/seeds/0001_staging_demo_seed.sql

# opção B (avançada): via psql
psql "$SUPABASE_DB_URL" -f infra/supabase/seeds/0001_staging_demo_seed.sql
```

## 4) Subir API
```bash
./scripts/staging-start-api.sh
```

## 5) Subir PWA
```bash
pnpm --filter web dev
```

## 6) Validar healthcheck
```bash
curl -i http://localhost:3001/health
```
Esperado: `HTTP/1.1 200` e payload com `{ "ok": true }`.

## Regras de segurança operacionais
- Sem produção.
- Sem dados reais.
- Sem segredos versionados.
- Sem cobrança real (a menos de `ALLOW_REAL_PAYMENTS=true` explícito).
- Sem WhatsApp real (a menos de `ALLOW_REAL_WHATSAPP=true` explícito).
- Sem IA livre (a menos de `ALLOW_REAL_AI=true` explícito).
- Deploy manual apenas (sem automação de produção).
