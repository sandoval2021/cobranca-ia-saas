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

create policy company_select_own on companies for select using (
  id in (select current_user_company_ids()) or current_user_is_super_admin()
);
create policy users_metadata_self on users_metadata for select using (id = auth.uid() or current_user_is_super_admin());
create policy members_own_company on company_members for select using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_customers_all on customers
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_servers_all on servers
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_server_routes_all on server_routes
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_apps_all on apps_catalog
for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());

create policy company_scoped_common_all on owner_profiles for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_links_all on customer_server_links for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_creds_all on customer_access_credentials for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_subs_all on company_subscriptions for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_mp_all on mp_connections for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_wa_all on whatsapp_connections for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_messages_all on messages for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy company_scoped_ai_all on ai_interactions for all using (company_id in (select current_user_company_ids()) or current_user_is_super_admin()) with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy audit_events_select on audit_events for select using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy audit_events_insert on audit_events for insert with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy sensitive_views_select on sensitive_data_views for select using (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy sensitive_views_insert on sensitive_data_views for insert with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
