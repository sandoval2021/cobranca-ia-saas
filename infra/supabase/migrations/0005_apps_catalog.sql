create table if not exists apps_catalog (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  name text not null,
  color text,
  requires_mac boolean not null default false,
  requires_key boolean not null default false,
  requires_username boolean not null default false,
  requires_password boolean not null default false,
  requires_link boolean not null default false,
  support_message text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, name)
);
