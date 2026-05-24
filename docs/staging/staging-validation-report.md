# Relatório de validação de staging (manual)

- **Data:** 2026-05-24
- **Branch:** `fase-8-validacao-staging-manual`
- **Escopo:** validação somente em staging com dados fictícios (sem produção, sem dados reais, sem integrações reais liberadas).

## 1) Motivo do status atual

O status segue **não pronto** até concluir execução real no staging online (Supabase staging + API/PWA staging) com evidências dos fluxos críticos.

## 2) Checklist operacional final (execução real no Supabase staging)

> **Regras fixas deste procedimento:**
> - Não usar produção.
> - Não usar dados reais.
> - Não ativar pagamentos reais.
> - Não ativar WhatsApp real.
> - Não ativar IA livre real.
> - Não versionar segredos.

### 2.1 Variáveis obrigatórias a configurar

Criar `.env.staging` local (não commitar) com placeholders:

```bash
STAGING_MODE=true
NODE_ENV=staging
APP_ENCRYPTION_KEY=<staging_app_encryption_key>
WEBHOOK_SHARED_SECRET=<staging_webhook_shared_secret>
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<staging_service_role_key>
SUPABASE_DB_URL=postgresql://postgres:<password>@db.<project-ref>.supabase.co:5432/postgres?sslmode=require

ALLOW_REAL_PAYMENTS=false
ALLOW_REAL_WHATSAPP=false
ALLOW_REAL_AI=false

# integrações sempre sandbox/mock
MERCADO_PAGO_CLIENT_ID=<sandbox_client_id>
MERCADO_PAGO_CLIENT_SECRET=<sandbox_client_secret>
EVOLUTION_API_URL=https://<sandbox-or-mock-endpoint>
EVOLUTION_API_KEY=<sandbox_or_mock_key>
OPENAI_API_KEY=<mock_or_limited_staging_key>
RESEND_API_KEY=<staging_or_mock_key>
```

Validar:

```bash
./scripts/staging-validate-env.sh .env.staging
```

### 2.2 Onde pegar o `SUPABASE_DB_URL`

No **projeto Supabase de staging**:
1. Acessar **Project Settings**.
2. Entrar em **Database**.
3. Copiar **Connection string** (URI) no formato Postgres.
4. Garantir que o host contém o `project-ref` de staging (ex.: `db.<project-ref>.supabase.co`) e **não** aponta para produção.
5. Salvar somente em `.env.staging` local ou secret manager de staging.

### 2.3 Como aplicar as migrations no staging

1. Validação estrutural local (já disponível):

```bash
./scripts/staging-validate-migrations.sh
```

2. Aplicação no banco staging (ordem 0001..0018):

```bash
set -a
source .env.staging
set +a

for f in $(ls infra/supabase/migrations/*.sql | sort); do
  echo "Aplicando $f"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```

3. Verificação pós-aplicação:

```bash
psql "$SUPABASE_DB_URL" -c "select count(*) as total_tables from information_schema.tables where table_schema='public';"
```



### 2.3.1 Alternativa sem `psql`: Supabase CLI (recomendada neste cenário)

1. Instalar/abrir Supabase CLI no ambiente seguro.
2. Autenticar:

```bash
supabase login
```

3. Obter `PROJECT_REF_STAGING` no dashboard Supabase:
   - **Project Settings** -> **General** -> **Reference ID**.
   - Confirmar que é do projeto staging (nome/URL de staging).

4. Linkar o diretório local ao projeto staging:

```bash
supabase link --project-ref <PROJECT_REF_STAGING>
```

5. Validar que o link está apontando para staging (não produção):

```bash
cat supabase/config.toml | rg 'project_id|project_ref'
```

6. Aplicar migrations pendentes:

```bash
./scripts/staging-validate-migrations.sh
supabase db push
```

7. Aplicar seed demo sem `psql`:

```bash
supabase db query < infra/supabase/seeds/0001_staging_demo_seed.sql
```

> Se preferir, manter `psql` como opção avançada (seção 2.3/2.4).

### 2.4 Como aplicar a seed demo

```bash
set -a
source .env.staging
set +a

psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f infra/supabase/seeds/0001_staging_demo_seed.sql
```

Conferência mínima:

```bash
psql "$SUPABASE_DB_URL" -c "select id,name from public.companies where id='11111111-1111-1111-1111-111111111111';"
psql "$SUPABASE_DB_URL" -c "select count(*) from public.customers where company_id='11111111-1111-1111-1111-111111111111';"
```

### 2.5 Como subir a API em modo staging

```bash
set -a
source .env.staging
set +a

./scripts/staging-start-api.sh
```

Critérios:
- inicialização sem erro crítico;
- sem warning de integração real ativada;
- `NODE_ENV` não pode ser `production`.

### 2.6 Como validar healthcheck

```bash
curl -i http://localhost:3001/health
```

Esperado:
- status HTTP `200`;
- payload com `ok=true` (ou equivalente de saúde positiva).

### 2.7 Como validar login / clientes / servidores / aplicativos

Usar `docs/staging/manual-validation.md` e executar com usuário demo:
1. Login e renovação de sessão.
2. Clientes: listagem + edição de cliente demo.
3. Servidores: CRUD demo + persistência.
4. Aplicativos: catálogo + vínculo/desvínculo demo.

Registrar para cada item:
- resultado (pass/fail);
- timestamp;
- print da tela;
- ID do tenant demo.

### 2.8 Como validar financeiro demo

1. Confirmar cobranças demo visíveis.
2. Simular mudança de status de cobrança (sem gateway real).
3. Confirmar vencimentos e transições esperadas em dados demo.

Evidências:
- print da listagem de cobranças;
- print do detalhe da cobrança alterada;
- log da operação simulada.

### 2.9 Como validar WhatsApp simulado

1. Garantir `ALLOW_REAL_WHATSAPP=false`.
2. Executar fluxo de envio simulado e confirmar gravação em tabela/log.
3. Processar webhook de teste (payload mock) e validar resultado.

Exemplo (endpoint ilustrativo):

```bash
curl -X POST http://localhost:3001/webhooks/whatsapp \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: <staging_webhook_shared_secret>" \
  -d '{"event":"message","mode":"simulated","from":"+550000000000","text":"ping staging"}'
```

### 2.10 Como validar IA simulada

1. Garantir `ALLOW_REAL_AI=false`.
2. Executar fluxo que usa resposta mock/simulada.
3. Validar fallback amigável em erro simulado de provedor.

Exemplo (endpoint ilustrativo):

```bash
curl -X POST http://localhost:3001/ai/simulate \
  -H "Content-Type: application/json" \
  -d '{"companyId":"11111111-1111-1111-1111-111111111111","prompt":"Status da cobrança demo"}'
```

### 2.11 Como coletar evidências

Para cada área (login, clientes, servidores, apps, financeiro, WhatsApp simulado, IA simulada, admin, mobile/PWA), coletar:
1. Checklist marcado (pass/fail).
2. Prints com timestamp visível.
3. Logs relevantes (trecho curto) sem segredos.
4. Identificação do ambiente (URL staging + commit hash).

Estrutura recomendada:

```text
docs/staging/evidence/
  2026-05-24/
    01-login.png
    02-clientes.png
    03-servidores.png
    04-apps.png
    05-financeiro.png
    06-whatsapp-simulado.png
    07-ia-simulada.png
    logs-sanitizados.md
```

### 2.12 Como decidir go/no-go

**GO (pronto para beta interno)** somente se:
- todos os itens bloqueantes concluídos;
- sem erro crítico de segurança/isolamento;
- sem integração real ativa;
- evidências completas anexadas.

**NO-GO (não pronto)** se qualquer um ocorrer:
- seed demo não aplicada no staging;
- fluxos críticos sem validação;
- ausência de evidências;
- qualquer indício de uso de produção/dados reais/integração real.

## 3) Comandos executados neste ciclo

```bash
./scripts/staging-validate-env.sh <tmp_env_file>
./scripts/staging-validate-migrations.sh
npm run build
git status --short
```

## 4) Decisão atual

- **Status atual:** ❌ **Não pronto**.
- **Falta para virar pronto:** executar checklist operacional acima no staging online e anexar evidências completas.


## 5) Execução real solicitada em 2026-05-24 (Supabase staging)

### 5.1 Resultado da tentativa neste ambiente de execução
- ✅ Branch ajustada para `fase-8-validacao-staging-manual`.
- ⚠️ Não foi possível validar envs de staging com `.env.staging` porque o arquivo não existe neste workspace.
- ✅ Validação estrutural de migrations executada (`18 migrations detectadas`).
- ⚠️ Não foi possível aplicar migrations/seed no Supabase staging neste runner porque `psql` não está instalado (`psql: command not found`).
- ⚠️ Healthcheck/API staging não pôde ser validado aqui sem env staging carregado e sem conexão operacional DB via `psql`.
- ✅ Build local executado com sucesso (`npm run build`).

### 5.2 Evidências de comandos executados
```bash
git checkout -B fase-8-validacao-staging-manual
./scripts/staging-validate-env.sh .env.staging
./scripts/staging-validate-migrations.sh
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f infra/supabase/migrations/0001_extensions_and_base.sql
npm run build
```

### 5.3 Bloqueios externos (não repositório)
1. Disponibilizar `.env.staging` no ambiente de execução (sem commit de segredos).
2. Ter Supabase CLI instalado e autenticado no ambiente seguro (`supabase login`).
3. Executar `supabase link --project-ref <PROJECT_REF_STAGING>` validando que o projeto linkado é staging.
4. (Opcional avançado) instalar cliente `psql` para execução direta por connection string.

### 5.4 Comandos prontos para você executar no ambiente seguro (com `psql`)
```bash
# 1) Validar envs
./scripts/staging-validate-env.sh .env.staging

# 2) Aplicar migrations em ordem
set -a
source .env.staging
set +a
for f in $(ls infra/supabase/migrations/*.sql | sort); do
  echo "Aplicando $f"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done

# 3) Aplicar seed demo
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f infra/supabase/seeds/0001_staging_demo_seed.sql

# 4) Subir API em staging
./scripts/staging-start-api.sh

# 5) Healthcheck
curl -i http://localhost:3001/health
```


### 5.5 Alternativa imediata para destravar sem `psql` (Supabase CLI)
```bash
# 0) autenticar
supabase login

# 1) linkar projeto staging (PROJECT_REF no dashboard -> Settings -> General -> Reference ID)
supabase link --project-ref <PROJECT_REF_STAGING>

# 2) validar que o link é staging
cat supabase/config.toml | rg 'project_id|project_ref'

# 3) aplicar migrations
./scripts/staging-validate-migrations.sh
supabase db push

# 4) aplicar seed demo sem psql
supabase db query < infra/supabase/seeds/0001_staging_demo_seed.sql
```

Confirmação: esta alternativa **ainda depende de execução manual no ambiente seguro** com credenciais de staging (sem produção e sem segredos no git).


## 6) Execução prática no SQL Editor do Supabase (staging)

Para execução manual direta no SQL Editor do projeto **staging**:

1. Rodar primeiro:
   - `docs/staging/manual-staging-full-schema.sql`
2. Rodar depois:
   - `docs/staging/manual-staging-seed.sql`
3. Validar carga mínima com queries:

```sql
select count(*) from companies;
select count(*) from customers;
```

Se os `count(*)` retornarem valores maiores que zero, o schema + seed base foram aplicados no staging.
