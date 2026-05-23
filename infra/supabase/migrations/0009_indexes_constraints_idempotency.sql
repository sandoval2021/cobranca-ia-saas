create index if not exists idx_customers_company_status on customers(company_id, status);
create index if not exists idx_customers_company_due_day on customers(company_id, due_day);
create index if not exists idx_servers_company_status on servers(company_id, status);
create index if not exists idx_messages_company_created_at on messages(company_id, created_at desc);
create index if not exists idx_audit_events_company_created_at on audit_events(company_id, created_at desc);
create unique index if not exists uq_messages_ext_msg_per_company on messages(company_id, external_message_id) where external_message_id is not null;
