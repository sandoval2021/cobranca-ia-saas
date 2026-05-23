alter table companies add column if not exists lifecycle_status text not null default 'teste' check (lifecycle_status in ('teste','ativa','bloqueada'));
alter table owner_profiles add column if not exists phone_e164 text;

alter table customers add column if not exists due_date date;
alter table customers add column if not exists app_id uuid references apps_catalog(id) on delete set null;
alter table customers add column if not exists primary_server_id uuid references servers(id) on delete set null;
alter table customers add column if not exists state_code text;
alter table customers add column if not exists service_plan text;

alter table customer_access_credentials add column if not exists link_dns_enc text;
alter table customer_access_credentials add column if not exists masked_preview text;

alter table servers add column if not exists fixed_link text;
alter table servers add column if not exists notes text;

alter table server_routes add column if not exists route_type text not null default 'principal' check (route_type in ('principal','reserva_1','reserva_2','reserva_3'));
alter table server_routes add column if not exists last_checked_at timestamptz;

create table if not exists server_route_switch_history (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  server_id uuid not null references servers(id) on delete cascade,
  from_route_id uuid references server_routes(id) on delete set null,
  to_route_id uuid references server_routes(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists customer_history_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  actor_user_id uuid references users_metadata(id) on delete set null,
  event_name text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_customers_company_name on customers(company_id, name);
create index if not exists idx_customers_company_whatsapp on customers(company_id, whatsapp_e164);
create index if not exists idx_customers_company_due_date on customers(company_id, due_date);
create index if not exists idx_routes_company_server_priority on server_routes(company_id, server_id, priority);
