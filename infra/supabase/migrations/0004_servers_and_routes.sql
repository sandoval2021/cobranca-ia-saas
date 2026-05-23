create table if not exists servers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  name text not null,
  color text,
  status server_status not null default 'ativo',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, name)
);

create table if not exists server_routes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  server_id uuid not null references servers(id) on delete cascade,
  route_name text not null,
  route_url text not null,
  status route_status not null default 'ativa',
  priority smallint not null default 1,
  is_healthy boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, server_id, route_name)
);
