alter table server_route_switch_history enable row level security;
alter table customer_history_events enable row level security;

create policy company_scoped_route_switch_all on server_route_switch_history
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_customer_history_all on customer_history_events
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
