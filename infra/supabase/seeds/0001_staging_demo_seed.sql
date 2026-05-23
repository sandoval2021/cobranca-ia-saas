-- Seed de staging com dados fictícios (NÃO usar em produção)
-- Objetivo: validar fluxos sem dados reais

begin;

-- Empresa demo
insert into public.companies (id, name, slug, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'Demo Company', 'demo-company', now())
on conflict (id) do nothing;

-- Clientes demo
insert into public.customers (id, company_id, name, email, phone, created_at)
values
  ('22222222-2222-2222-2222-222222222221', '11111111-1111-1111-1111-111111111111', 'Cliente Demo 1', 'cliente1.demo@example.com', '+550000000001', now()),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Cliente Demo 2', 'cliente2.demo@example.com', '+550000000002', now())
on conflict (id) do nothing;

-- Servidores demo
insert into public.servers (id, company_id, name, host, status, created_at)
values
  ('33333333-3333-3333-3333-333333333331', '11111111-1111-1111-1111-111111111111', 'Servidor Demo 1', 'srv-demo-1.local', 'active', now()),
  ('33333333-3333-3333-3333-333333333332', '11111111-1111-1111-1111-111111111111', 'Servidor Demo 2', 'srv-demo-2.local', 'maintenance', now())
on conflict (id) do nothing;

-- Aplicativos demo
insert into public.apps_catalog (id, name, code, created_at)
values
  ('44444444-4444-4444-4444-444444444441', 'Demo App Core', 'demo-app-core', now()),
  ('44444444-4444-4444-4444-444444444442', 'Demo App Finance', 'demo-app-finance', now())
on conflict (id) do nothing;

-- Cobranças demo
insert into public.subscriptions (id, company_id, customer_id, plan_code, status, amount_cents, created_at)
values
  ('55555555-5555-5555-5555-555555555551', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222221', 'demo-basic', 'active', 9900, now()),
  ('55555555-5555-5555-5555-555555555552', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'demo-pro', 'past_due', 19900, now())
on conflict (id) do nothing;

-- WhatsApp simulado
insert into public.messages (id, company_id, customer_id, channel, direction, body, status, created_at)
values
  ('66666666-6666-6666-6666-666666666661', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222221', 'whatsapp', 'outbound', '[SIMULADO] Olá, esta é uma mensagem de staging.', 'sent', now()),
  ('66666666-6666-6666-6666-666666666662', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'whatsapp', 'inbound', '[SIMULADO] Recebido com sucesso em staging.', 'received', now())
on conflict (id) do nothing;

-- IA simulada
insert into public.ai_messages (id, company_id, customer_id, prompt, response, provider, model, created_at)
values
  ('77777777-7777-7777-7777-777777777771', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222221', 'Qual o status da cobrança?', '[SIMULADO] A cobrança está ativa no ambiente de staging.', 'mock', 'mock-gpt', now()),
  ('77777777-7777-7777-7777-777777777772', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'Gerar resumo do cliente.', '[SIMULADO] Cliente demo com uso de dados fictícios.', 'mock', 'mock-gpt', now())
on conflict (id) do nothing;

commit;
