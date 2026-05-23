alter table billing_plans enable row level security;
alter table subscription_events enable row level security;
alter table customer_charges enable row level security;
alter table payment_transactions enable row level security;
alter table payment_webhook_events enable row level security;
alter table platform_fee_ledger enable row level security;
alter table renewal_tasks enable row level security;
alter table renewal_task_events enable row level security;
alter table financial_audit_events enable row level security;

create policy billing_plans_read on billing_plans for select using (true);

create policy company_scoped_subscription_events on subscription_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_charges on customer_charges for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_transactions on payment_transactions for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_webhook_events on payment_webhook_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_fee_ledger on platform_fee_ledger for select
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_fee_ledger_insert on platform_fee_ledger for insert
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_renewal_tasks on renewal_tasks for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_renewal_events on renewal_task_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy fin_audit_select on financial_audit_events for select
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy fin_audit_insert on financial_audit_events for insert
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
