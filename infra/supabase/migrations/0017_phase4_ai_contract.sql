create table if not exists ai_company_settings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  enabled boolean not null default false,
  model_primary text not null default 'gpt-4o-mini',
  model_fallback text not null default 'gpt-4o-mini',
  daily_token_limit integer not null default 200000,
  monthly_token_limit integer not null default 3000000,
  daily_cost_limit_cents integer not null default 3000,
  monthly_cost_limit_cents integer not null default 50000,
  consumed_daily_tokens integer not null default 0,
  consumed_monthly_tokens integer not null default 0,
  consumed_daily_cost_cents integer not null default 0,
  consumed_monthly_cost_cents integer not null default 0,
  operating_hours jsonb not null default '{}'::jsonb,
  allowed_message_types jsonb not null default '["cobranca","suporte","duvida"]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id)
);

create table if not exists ai_conversations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  thread_key text not null,
  status text not null default 'ia_ativa',
  locked boolean not null default false,
  lock_until timestamptz,
  human_required boolean not null default false,
  last_inbound_at timestamptz,
  last_outbound_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, thread_key)
);

create table if not exists ai_intent_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  conversation_id uuid references ai_conversations(id) on delete set null,
  message_id uuid,
  intent text not null,
  confidence numeric(5,4),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists ai_messages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  conversation_id uuid references ai_conversations(id) on delete set null,
  direction text not null,
  prompt text,
  response text,
  model_used text,
  tokens_input integer not null default 0,
  tokens_output integer not null default 0,
  cost_cents integer not null default 0,
  latency_ms integer,
  origin text,
  created_at timestamptz not null default now()
);

create table if not exists ai_guardrail_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  conversation_id uuid references ai_conversations(id) on delete set null,
  event_name text not null,
  blocked_action text not null,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists ai_handoff_queue (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  conversation_id uuid not null references ai_conversations(id) on delete cascade,
  status text not null default 'precisa_humano',
  assigned_user_id uuid references users_metadata(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, conversation_id)
);

create table if not exists ai_loop_protection (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  conversation_id uuid not null references ai_conversations(id) on delete cascade,
  dedup_key text not null,
  window_seconds integer not null default 120,
  hit_count integer not null default 1,
  cooldown_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, dedup_key)
);

create table if not exists ai_memory_snapshots (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  conversation_id uuid not null references ai_conversations(id) on delete cascade,
  summary text not null,
  facts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ai_conv_company_status on ai_conversations(company_id, status, updated_at desc);
create index if not exists idx_ai_msg_company_created on ai_messages(company_id, created_at desc);
create index if not exists idx_ai_guard_company_created on ai_guardrail_events(company_id, created_at desc);
