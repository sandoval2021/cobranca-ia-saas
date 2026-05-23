create type if not exists charge_status as enum ('pendente','aprovado','falhou','cancelado','expirado');
create type if not exists renewal_status as enum ('pendente','concluida','cancelada');

alter table company_subscriptions alter column status type text;
alter table company_subscriptions add column if not exists trial_started_at timestamptz;
alter table company_subscriptions add column if not exists partial_blocked boolean not null default false;

create table if not exists billing_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  amount_cents integer not null,
  interval_months smallint not null default 1,
  trial_days smallint not null default 7,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists subscription_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  subscription_id uuid not null references company_subscriptions(id) on delete cascade,
  event_name text not null,
  from_status text,
  to_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists customer_charges (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  external_reference text not null,
  provider_charge_id text,
  payment_link text,
  amount_cents integer not null,
  platform_fee_cents integer not null,
  provider_fee_cents integer not null default 0,
  estimated_net_cents integer not null,
  status charge_status not null default 'pendente',
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, external_reference)
);

create table if not exists payment_transactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  charge_id uuid not null references customer_charges(id) on delete cascade,
  provider_payment_id text not null,
  provider_status text not null,
  paid_amount_cents integer,
  provider_fee_cents integer,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(company_id, provider_payment_id)
);

create table if not exists payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  provider_event_id text not null,
  provider_name text not null default 'mercado_pago',
  event_type text,
  signature_valid boolean not null default false,
  processed boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  unique(company_id, provider_event_id)
);

create table if not exists platform_fee_ledger (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  charge_id uuid not null references customer_charges(id) on delete cascade,
  fee_percent numeric(5,2) not null,
  fee_cents integer not null,
  base_amount_cents integer not null,
  created_at timestamptz not null default now(),
  unique(company_id, charge_id)
);

create table if not exists renewal_tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  charge_id uuid not null references customer_charges(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  status renewal_status not null default 'pendente',
  confirmed_by_user_id uuid references users_metadata(id) on delete set null,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(company_id, charge_id)
);

create table if not exists renewal_task_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  renewal_task_id uuid not null references renewal_tasks(id) on delete cascade,
  event_name text not null,
  actor_user_id uuid references users_metadata(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists financial_audit_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  actor_user_id uuid references users_metadata(id) on delete set null,
  event_name text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_charges_company_status_created on customer_charges(company_id, status, created_at desc);
create index if not exists idx_webhook_company_processed on payment_webhook_events(company_id, processed, created_at desc);
create index if not exists idx_financial_audit_company_created on financial_audit_events(company_id, created_at desc);
