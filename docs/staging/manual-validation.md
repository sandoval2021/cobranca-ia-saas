# Guia de validação manual (staging)

> Atualizado em 2026-05-24: checklist funcional ainda pendente de execução em staging online.

## Pré-condições
- Staging publicado com dados fictícios.
- Sem integrações reais habilitadas.

## 1. Login
- [ ] Login com usuário demo funciona.
- [ ] Sessão expira e renova corretamente.

## 2. Clientes
- [ ] Listagem de clientes demo.
- [ ] Criação/edição/remoção sem impactar dados externos.

## 3. Servidores
- [ ] CRUD de servidores demo funcionando.
- [ ] Rotas e vínculos persistem corretamente.

## 4. Aplicativos
- [ ] Catálogo de apps carrega.
- [ ] Vincular/desvincular app em cliente demo.

## 5. Financeiro
- [ ] Cobranças demo visíveis.
- [ ] Mudança de status de cobrança simulada.

## 6. WhatsApp
- [ ] Envio simulado registra mensagem.
- [ ] Webhook de teste é processado.

## 7. IA
- [ ] Fluxo com resposta simulada estável.
- [ ] Erro de provedor é tratado com fallback amigável.

## 8. Mobile/PWA
- [ ] App instalável no navegador mobile.
- [ ] Tela offline disponível sem quebra.

## 9. Admin
- [ ] Operações administrativas limitadas ao tenant demo.
- [ ] Auditoria básica de ações sensíveis registrada.
