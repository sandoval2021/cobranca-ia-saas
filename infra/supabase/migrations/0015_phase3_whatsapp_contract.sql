create type if not exists wa_instance_status as enum ('conectado','desconectado','pausado','falha');
create type if not exists wa_queue_status as enum ('pendente','enviando','enviado','falha_retry','falha_final','pausado');
create type if not exists wa_msg_direction as enum ('saida','entrada');

create table if not exists wa_instances (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  instance_name text not null,
  status wa_instance_status not null default 'desconectado',
  is_connected boolean not null default false,
  last_connected_at timestamptz,
  qr_code text,
  fail_count integer not null default 0,
  blocked boolean not null default false,
  daily_limit integer not null default 300,
  sent_today integer not null default 0,
  cooldown_until timestamptz,
  token_enc text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id)
);

create table if not exists wa_instance_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  wa_instance_id uuid not null references wa_instances(id) on delete cascade,
  event_name text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists wa_dedup_registry (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  dedup_key text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique(company_id, dedup_key)
);

create table if not exists wa_outbox_queue (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  wa_instance_id uuid not null references wa_instances(id) on delete cascade,
  dedup_key text not null,
  msg_type text not null default 'texto',
  payload jsonb not null default '{}'::jsonb,
  priority smallint not null default 5,
  status wa_queue_status not null default 'pendente',
  attempts integer not null default 0,
  max_attempts integer not null default 4,
  next_retry_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, dedup_key)
);

create table if not exists wa_messages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  wa_instance_id uuid not null references wa_instances(id) on delete cascade,
  queue_id uuid references wa_outbox_queue(id) on delete set null,
  provider_message_id text,
  direction wa_msg_direction not null,
  msg_type text not null default 'texto',
  content text,
  media_url text,
  status text not null,
  fail_reason text,
  sent_at timestamptz,
  received_at timestamptz,
  created_at timestamptz not null default now(),
  unique(company_id, provider_message_id)
);

create table if not exists wa_webhook_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  provider_event_id text not null,
  event_type text,
  payload jsonb not null default '{}'::jsonb,
  signature_valid boolean not null default false,
  processed boolean not null default false,
  created_at timestamptz not null default now(),
  unique(company_id, provider_event_id)
);

create index if not exists idx_wa_queue_company_status_priority on wa_outbox_queue(company_id, status, priority, created_at);
create index if not exists idx_wa_messages_company_created on wa_messages(company_id, created_at desc);
create index if not exists idx_wa_webhook_company_processed on wa_webhook_events(company_id, processed, created_at desc);
