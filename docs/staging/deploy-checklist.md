# Checklist de deploy em staging

> **Escopo:** validar staging com segurança. **Não executar em produção.**

## 1) Banco de dados
- [ ] Projeto Supabase de staging criado e isolado.
- [ ] Backups/snapshots iniciais habilitados.

## 2) Migrations
- [x] Todas as migrations em `infra/supabase/migrations` validadas estruturalmente sem erro (`./scripts/staging-validate-migrations.sh`).
- [x] Estrutura/ordem de migrations conferida (0001..0018).

## 3) RLS
- [x] RLS habilitado nas tabelas multi-tenant (policies em 0010/0012/0014/0016/0018).
- [ ] Policies de leitura/escrita testadas com usuário não-admin.

## 4) Envs
- [ ] Arquivo `.env.staging` preenchido com segredos de staging (pendente no ambiente alvo).
- [x] Script de validação de env executado com sucesso (arquivo temporário sem segredos reais).

## 5) Healthcheck
- [ ] API sobe sem erro.
- [ ] Endpoint de healthcheck responde 200.

## 6) PWA
- [ ] `manifest.webmanifest` carregado.
- [ ] `sw.js` registrado sem erro.
- [ ] `offline.html` acessível em modo offline.

## 7) Webhooks
- [ ] Webhooks apontam para URL de staging.
- [ ] Assinatura validada com `WEBHOOK_SHARED_SECRET` de staging.

## 8) Logs e observabilidade
- [ ] Logs sem erro crítico na inicialização.
- [ ] Correlação de request (`request-context`) ativa.

## 9) Rollback
- [ ] Plano de rollback documentado (tag de release + restore DB).
- [ ] Procedimento ensaiado em ambiente de staging.
