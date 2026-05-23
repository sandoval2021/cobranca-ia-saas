# Checklist de deploy em staging

> **Escopo:** validar staging com segurança. **Não executar em produção.**

## 1) Banco de dados
- [ ] Projeto Supabase de staging criado e isolado.
- [ ] Backups/snapshots iniciais habilitados.

## 2) Migrations
- [ ] Todas as migrations em `infra/supabase/migrations` aplicadas sem erro.
- [ ] Estrutura final conferida (tabelas, índices e constraints).

## 3) RLS
- [ ] RLS habilitado nas tabelas multi-tenant.
- [ ] Policies de leitura/escrita testadas com usuário não-admin.

## 4) Envs
- [ ] Arquivo `.env.staging` preenchido com segredos de staging.
- [ ] Script de validação de env executado com sucesso.

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
