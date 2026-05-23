alter table wa_instances enable row level security;
alter table wa_instance_events enable row level security;
alter table wa_dedup_registry enable row level security;
alter table wa_outbox_queue enable row level security;
alter table wa_messages enable row level security;
alter table wa_webhook_events enable row level security;

create policy wa_instances_scope on wa_instances for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy wa_events_scope on wa_instance_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy wa_dedup_scope on wa_dedup_registry for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy wa_queue_scope on wa_outbox_queue for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy wa_messages_scope on wa_messages for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy wa_webhook_scope on wa_webhook_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
