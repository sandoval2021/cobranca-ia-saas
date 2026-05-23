create table if not exists company_subscriptions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  status subscription_status not null default 'trial',
  trial_ends_at timestamptz,
  current_period_ends_at timestamptz,
  monthly_amount_cents integer not null default 3000,
  blocked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id)
);

create table if not exists mp_connections (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  mp_user_id text,
  access_token_enc text,
  refresh_token_enc text,
  connected_at timestamptz,
  status text not null default 'disconnected',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id)
);

create table if not exists whatsapp_connections (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  phone_e164 text,
  evolution_instance_id text,
  status text not null default 'desconectado',
  paused_by_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id)
);
