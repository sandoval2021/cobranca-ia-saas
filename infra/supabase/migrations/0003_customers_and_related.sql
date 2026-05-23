create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  name text not null,
  whatsapp_e164 text not null,
  amount_cents integer not null,
  due_day smallint not null,
  status text not null default 'em_dia',
  app_id uuid,
  primary_server_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, whatsapp_e164)
);

create table if not exists customer_server_links (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  server_id uuid not null,
  link_type text not null check (link_type in ('principal','alternativo')),
  created_at timestamptz not null default now(),
  unique(company_id, customer_id, server_id)
);

create table if not exists customer_access_credentials (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  username_enc text,
  password_enc text,
  mac_enc text,
  key_enc text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, customer_id)
);
