-- Seed de staging com dados fictícios (NÃO usar em produção)
-- Objetivo: validar fluxos sem dados reais

begin;

-- Empresa demo
insert into public.companies (id, name, slug, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'Demo Company', 'demo-company', now())
on conflict (id) do nothing;

-- Servidores demo
insert into public.servers (id, company_id, name, color, status, created_at)
values
  ('33333333-3333-3333-3333-333333333331', '11111111-1111-1111-1111-111111111111', 'Servidor Demo 1', '#2563eb', 'ativo', now()),
  ('33333333-3333-3333-3333-333333333332', '11111111-1111-1111-1111-111111111111', 'Servidor Demo 2', '#f59e0b', 'instavel', now())
on conflict (id) do nothing;

-- Aplicativos demo
insert into public.apps_catalog (
  id,
  company_id,
  name,
  color,
  requires_mac,
  requires_key,
  requires_username,
  requires_password,
  requires_link,
  support_message,
  notes,
  created_at
)
values
  (
    '44444444-4444-4444-4444-444444444441',
    '11111111-1111-1111-1111-111111111111',
    'Demo App Core',
    '#22c55e',
    false,
    false,
    true,
    true,
    true,
    '[SIMULADO] Suporte de staging para app core.',
    '[SIMULADO] Dados fictícios para testes.',
    now()
  ),
  (
    '44444444-4444-4444-4444-444444444442',
    '11111111-1111-1111-1111-111111111111',
    'Demo App Finance',
    '#a855f7',
    false,
    true,
    true,
    true,
    false,
    '[SIMULADO] Suporte de staging para app financeiro.',
    '[SIMULADO] Dados fictícios para validação.',
    now()
  )
on conflict (id) do nothing;

-- Clientes demo (colunas compatíveis com schema atual)
insert into public.customers (
  id,
  company_id,
  name,
  whatsapp_e164,
  amount_cents,
  due_day,
  status,
  app_id,
  primary_server_id,
  notes,
  due_date,
  state_code,
  service_plan,
  created_at
)
values
  (
    '22222222-2222-2222-2222-222222222221',
    '11111111-1111-1111-1111-111111111111',
    'Cliente Demo 1',
    '+550000000001',
    9900,
    10,
    'em_dia',
    '44444444-4444-4444-4444-444444444441',
    '33333333-3333-3333-3333-333333333331',
    '[SIMULADO] Cliente de staging sem dados reais.',
    current_date + interval '10 days',
    'SP',
    'demo-basic',
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'Cliente Demo 2',
    '+550000000002',
    19900,
    20,
    'atrasado',
    '44444444-4444-4444-4444-444444444442',
    '33333333-3333-3333-3333-333333333332',
    '[SIMULADO] Cliente de staging com atraso fictício.',
    current_date - interval '3 days',
    'RJ',
    'demo-pro',
    now()
  )
on conflict (id) do nothing;

-- Assinatura da empresa (substitui tabela antiga subscriptions)
insert into public.company_subscriptions (
  id,
  company_id,
  status,
  trial_started_at,
  trial_ends_at,
  current_period_ends_at,
  monthly_amount_cents,
  created_at
)
values
  (
    '55555555-5555-5555-5555-555555555551',
    '11111111-1111-1111-1111-111111111111',
    'active',
    now() - interval '5 days',
    now() + interval '2 days',
    now() + interval '32 days',
    3000,
    now()
  )
on conflict (id) do nothing;

-- Cobranças demo
insert into public.customer_charges (
  id,
  company_id,
  customer_id,
  external_reference,
  provider_charge_id,
  payment_link,
  amount_cents,
  platform_fee_cents,
  provider_fee_cents,
  estimated_net_cents,
  status,
  due_at,
  created_at
)
values
  (
    '88888888-8888-8888-8888-888888888881',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222221',
    'stg-charge-0001',
    'mock-provider-0001',
    'https://example.com/pay/stg-charge-0001',
    9900,
    500,
    100,
    9300,
    'pendente',
    now() + interval '2 days',
    now()
  ),
  (
    '88888888-8888-8888-8888-888888888882',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'stg-charge-0002',
    'mock-provider-0002',
    'https://example.com/pay/stg-charge-0002',
    19900,
    1000,
    200,
    18700,
    'aprovado',
    now() - interval '1 day',
    now()
  )
on conflict (id) do nothing;

-- WhatsApp simulado
insert into public.messages (
  id,
  company_id,
  customer_id,
  direction,
  external_message_id,
  dedup_key,
  content,
  sent_at,
  received_at,
  created_at
)
values
  (
    '66666666-6666-6666-6666-666666666661',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222221',
    'saida',
    'stg-ext-msg-0001',
    'stg-dedup-0001',
    '[SIMULADO] Olá, esta é uma mensagem de staging.',
    now() - interval '30 minutes',
    null,
    now()
  ),
  (
    '66666666-6666-6666-6666-666666666662',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'entrada',
    'stg-ext-msg-0002',
    'stg-dedup-0002',
    '[SIMULADO] Recebido com sucesso em staging.',
    null,
    now() - interval '10 minutes',
    now()
  )
on conflict (id) do nothing;

-- IA simulada
insert into public.ai_messages (
  id,
  company_id,
  direction,
  prompt,
  response,
  model_used,
  tokens_input,
  tokens_output,
  cost_cents,
  latency_ms,
  origin,
  created_at
)
values
  (
    '77777777-7777-7777-7777-777777777771',
    '11111111-1111-1111-1111-111111111111',
    'entrada',
    'Qual o status da cobrança?',
    '[SIMULADO] A cobrança está ativa no ambiente de staging.',
    'mock-gpt',
    32,
    54,
    1,
    420,
    'staging-seed',
    now()
  ),
  (
    '77777777-7777-7777-7777-777777777772',
    '11111111-1111-1111-1111-111111111111',
    'saida',
    'Gerar resumo do cliente.',
    '[SIMULADO] Cliente demo com uso de dados fictícios.',
    'mock-gpt',
    28,
    46,
    1,
    390,
    'staging-seed',
    now()
  )
on conflict (id) do nothing;

commit;
