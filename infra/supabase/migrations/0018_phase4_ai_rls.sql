alter table ai_company_settings enable row level security;
alter table ai_conversations enable row level security;
alter table ai_intent_events enable row level security;
alter table ai_messages enable row level security;
alter table ai_guardrail_events enable row level security;
alter table ai_handoff_queue enable row level security;
alter table ai_loop_protection enable row level security;
alter table ai_memory_snapshots enable row level security;

create policy ai_settings_scope on ai_company_settings for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_conversations_scope on ai_conversations for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_intents_scope on ai_intent_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_messages_scope on ai_messages for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_guard_scope on ai_guardrail_events for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_handoff_scope on ai_handoff_queue for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_loop_scope on ai_loop_protection for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
create policy ai_memory_scope on ai_memory_snapshots for all
using (company_id in (select current_user_company_ids()) or current_user_is_super_admin())
with check (company_id in (select current_user_company_ids()) or current_user_is_super_admin());
