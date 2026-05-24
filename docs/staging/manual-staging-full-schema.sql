-- MANUAL STAGING FULL SCHEMA
-- Auxiliar para execução manual no Supabase STAGING somente.
-- NÃO usar em produção.

-- ==================================================
-- MIGRATION 0001_extensions_and_base.sql
-- ==================================================

create extension if not exists pgcrypto;

do $$
begin
  create type app_role as enum ('super_admin', 'owner');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type subscription_status as enum ('trial', 'active', 'past_due', 'paused', 'blocked', 'canceled');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type server_status as enum ('ativo', 'instavel', 'fora_do_ar');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type route_status as enum ('ativa', 'reserva', 'inativa');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type message_direction as enum ('entrada', 'saida');
exception
  when duplicate_object then null;
end $$;

-- ==================================================
-- MIGRATION 0002_companies_and_users_metadata.sql
-- ==================================================

create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists users_metadata (
  id uuid primary key,
  email text not null unique,
  whatsapp_e164 text not null unique,
  email_confirmed boolean not null default false,
  blocked_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists company_members (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references users_metadata(id) on delete cascade,
  role app_role not null,
  created_at timestamptz not null default now(),
  unique(company_id, user_id)
);

create table if not exists owner_profiles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references users_metadata(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, user_id)
);

-- ==================================================
-- MIGRATION 0003_customers_and_related.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0004_servers_and_routes.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0005_apps_catalog.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0006_subscriptions_and_connections.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0007_messages_and_ai.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0008_audit_and_sensitive_views.sql
-- ==================================================

create table if not exists audit_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references companies(id) on delete set null,
  actor_user_id uuid references users_metadata(id) on delete set null,
  event_name text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists sensitive_data_views (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  actor_user_id uuid references users_metadata(id) on delete set null,
  entity_type text not null,
  entity_id uuid not null,
  reason text,
  created_at timestamptz not null default now()
);

-- ==================================================
-- MIGRATION 0009_indexes_constraints_idempotency.sql
-- ==================================================

create index if not exists idx_customers_company_status on customers(company_id, status);
create index if not exists idx_customers_company_due_day on customers(company_id, due_day);
create index if not exists idx_servers_company_status on servers(company_id, status);
create index if not exists idx_messages_company_created_at on messages(company_id, created_at desc);
create index if not exists idx_audit_events_company_created_at on audit_events(company_id, created_at desc);
create unique index if not exists uq_messages_ext_msg_per_company on messages(company_id, external_message_id) where external_message_id is not null;

-- ==================================================
-- MIGRATION 0010_rls_enable_and_policies.sql
-- ==================================================

create or replace function public.current_user_is_super_admin()
returns boolean language sql stable as $$
  select exists (
    select 1 from company_members cm
    where cm.user_id = auth.uid() and cm.role = 'super_admin'
  );
$$;

create or replace function public.current_user_company_ids()
returns setof uuid language sql stable as $$
  select cm.company_id from company_members cm where cm.user_id = auth.uid();
$$;

alter table companies enable row level security;
alter table users_metadata enable row level security;
alter table company_members enable row level security;
alter table owner_profiles enable row level security;
alter table customers enable row level security;
alter table customer_server_links enable row level security;
alter table customer_access_credentials enable row level security;
alter table servers enable row level security;
alter table server_routes enable row level security;
alter table apps_catalog enable row level security;
alter table company_subscriptions enable row level security;
alter table mp_connections enable row level security;
alter table whatsapp_connections enable row level security;
alter table messages enable row level security;
alter table ai_interactions enable row level security;
alter table audit_events enable row level security;
alter table sensitive_data_views enable row level security;

do $$
begin
  create policy company_select_own on companies for select using (
  id in (select current_user_company_ids()) or current_user_is_super_admin()
);
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy users_metadata_self on users_metadata for select using (id = auth.uid() or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy members_own_company on company_members for select using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_customers_all on customers
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_servers_all on servers
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_server_routes_all on server_routes
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_apps_all on apps_catalog
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_common_all on owner_profiles for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_links_all on customer_server_links for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_creds_all on customer_access_credentials for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_subs_all on company_subscriptions for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_mp_all on mp_connections for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_wa_all on whatsapp_connections for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_messages_all on messages for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_ai_all on ai_interactions for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy audit_events_select on audit_events for select using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy audit_events_insert on audit_events for insert with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy sensitive_views_select on sensitive_data_views for select using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy sensitive_views_insert on sensitive_data_views for insert with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

-- ==================================================
-- MIGRATION 0011_phase1_operational_base.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0012_phase1_rls_policies.sql
-- ==================================================

alter table server_route_switch_history enable row level security;
alter table customer_history_events enable row level security;

do $$
begin
  create policy company_scoped_route_switch_all on server_route_switch_history
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_customer_history_all on customer_history_events
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

-- ==================================================
-- MIGRATION 0013_phase2_financial_contract.sql
-- ==================================================

do $$
begin
  create type charge_status as enum ('pendente','aprovado','falhou','cancelado','expirado');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type renewal_status as enum ('pendente','concluida','cancelada');
exception
  when duplicate_object then null;
end $$;

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

-- ==================================================
-- MIGRATION 0014_phase2_financial_rls.sql
-- ==================================================

alter table billing_plans enable row level security;
alter table subscription_events enable row level security;
alter table customer_charges enable row level security;
alter table payment_transactions enable row level security;
alter table payment_webhook_events enable row level security;
alter table platform_fee_ledger enable row level security;
alter table renewal_tasks enable row level security;
alter table renewal_task_events enable row level security;
alter table financial_audit_events enable row level security;

do $$
begin
  create policy billing_plans_read on billing_plans for select using (true);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_subscription_events on subscription_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_charges on customer_charges for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_transactions on payment_transactions for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_webhook_events on payment_webhook_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_fee_ledger on platform_fee_ledger for select
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy company_scoped_fee_ledger_insert on platform_fee_ledger for insert
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_renewal_tasks on renewal_tasks for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy company_scoped_renewal_events on renewal_task_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy fin_audit_select on financial_audit_events for select
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy fin_audit_insert on financial_audit_events for insert
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

-- ==================================================
-- MIGRATION 0015_phase3_whatsapp_contract.sql
-- ==================================================

do $$
begin
  create type wa_instance_status as enum ('conectado','desconectado','pausado','falha');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type wa_queue_status as enum ('pendente','enviando','enviado','falha_retry','falha_final','pausado');
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create type wa_msg_direction as enum ('saida','entrada');
exception
  when duplicate_object then null;
end $$;

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

-- ==================================================
-- MIGRATION 0016_phase3_whatsapp_rls.sql
-- ==================================================

alter table wa_instances enable row level security;
alter table wa_instance_events enable row level security;
alter table wa_dedup_registry enable row level security;
alter table wa_outbox_queue enable row level security;
alter table wa_messages enable row level security;
alter table wa_webhook_events enable row level security;

do $$
begin
  create policy wa_instances_scope on wa_instances for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy wa_events_scope on wa_instance_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy wa_dedup_scope on wa_dedup_registry for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy wa_queue_scope on wa_outbox_queue for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy wa_messages_scope on wa_messages for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy wa_webhook_scope on wa_webhook_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

-- ==================================================
-- MIGRATION 0017_phase4_ai_contract.sql
-- ==================================================

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

-- ==================================================
-- MIGRATION 0018_phase4_ai_rls.sql
-- ==================================================

alter table ai_company_settings enable row level security;
alter table ai_conversations enable row level security;
alter table ai_intent_events enable row level security;
alter table ai_messages enable row level security;
alter table ai_guardrail_events enable row level security;
alter table ai_handoff_queue enable row level security;
alter table ai_loop_protection enable row level security;
alter table ai_memory_snapshots enable row level security;

do $$
begin
  create policy ai_settings_scope on ai_company_settings for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_conversations_scope on ai_conversations for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_intents_scope on ai_intent_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_messages_scope on ai_messages for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_guard_scope on ai_guardrail_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_handoff_scope on ai_handoff_queue for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_loop_scope on ai_loop_protection for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;
do $$
begin
  create policy ai_memory_scope on ai_memory_snapshots for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
exception
  when duplicate_object then null;
end $$;

