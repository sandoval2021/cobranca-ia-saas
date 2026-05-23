create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  whatsapp_connection_id uuid references whatsapp_connections(id) on delete set null,
  direction message_direction not null,
  external_message_id text,
  dedup_key text,
  content text not null,
  sent_at timestamptz,
  received_at timestamptz,
  created_at timestamptz not null default now(),
  unique(company_id, dedup_key)
);

create table if not exists ai_interactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  message_id uuid references messages(id) on delete set null,
  model text,
  prompt_tokens integer,
  completion_tokens integer,
  decision text,
  escalation_required boolean not null default false,
  created_at timestamptz not null default now()
);
