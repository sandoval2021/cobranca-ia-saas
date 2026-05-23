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
