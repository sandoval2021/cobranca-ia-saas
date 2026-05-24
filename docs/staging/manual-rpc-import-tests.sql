-- Manual tests for public.staging_import_customers_from_rows on staging
-- Execute in Supabase SQL editor with appropriate session role/JWT contexts.

-- 0) Validate function and grants
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as args,
  p.prosecdef as is_security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'staging_import_customers_from_rows';

select grantee, privilege_type
from information_schema.routine_privileges
where specific_schema = 'public'
  and routine_name = 'staging_import_customers_from_rows'
order by grantee, privilege_type;

-- 1) anon cannot execute
-- Expected: permission denied / unauthorized
-- In SQL Editor with anon JWT context:
select public.staging_import_customers_from_rows(
  '00000000-0000-0000-0000-000000000000'::uuid,
  '[]'::jsonb
);

-- 2) authenticated authorized user can execute
-- Replace with a real company_id the authenticated user belongs to.
select public.staging_import_customers_from_rows(
  '11111111-1111-1111-1111-111111111111'::uuid,
  jsonb_build_array(
    jsonb_build_object(
      'external_code','86',
      'external_customer_code','86',
      'customer_name','Cliente Teste',
      'whatsapp_e164','+55 (62) 99578-8040',
      'service_name','1 MÊS',
      'amount_cents',2990,
      'expires_at','2026-06-19',
      'situation','Ativo',
      'raw_row',jsonb_build_object('src','manual_test')
    )
  )
);

-- 3) authenticated user without access to company is denied
-- Expected: Sem permissão para importar dados para esta empresa.
select public.staging_import_customers_from_rows(
  '22222222-2222-2222-2222-222222222222'::uuid,
  jsonb_build_array(
    jsonb_build_object('whatsapp_e164','+5562999999999','customer_name','SemPermissao')
  )
);

-- 4) import creates/updates customer and deduplicates by company + whatsapp
-- Run twice; first should import, second should update (not create duplicate customer).
select public.staging_import_customers_from_rows(
  '11111111-1111-1111-1111-111111111111'::uuid,
  jsonb_build_array(
    jsonb_build_object(
      'external_code','DUP-001',
      'external_customer_code','DUP-001',
      'customer_name','Cliente Duplicado',
      'whatsapp_e164','+55 62 99578-8040',
      'service_name','Plano X',
      'amount_cents',4500,
      'expires_at','2026-07-10',
      'situation','Ativo',
      'raw_row',jsonb_build_object('round',1)
    )
  )
);

select public.staging_import_customers_from_rows(
  '11111111-1111-1111-1111-111111111111'::uuid,
  jsonb_build_array(
    jsonb_build_object(
      'external_code','DUP-001',
      'external_customer_code','DUP-001',
      'customer_name','Cliente Duplicado Atualizado',
      'whatsapp_e164','(62) 99578-8040',
      'service_name','Plano X',
      'amount_cents',4900,
      'expires_at','2026-07-15',
      'situation','Ativo',
      'raw_row',jsonb_build_object('round',2)
    )
  )
);

-- 5) charge is created/updated in staging
select c.id as customer_id, c.company_id, c.whatsapp_e164, c.name, c.amount_cents, c.due_day
from public.customers c
where c.company_id = '11111111-1111-1111-1111-111111111111'::uuid
  and c.whatsapp_e164 = '+5562995788040';

select cc.id as charge_id, cc.company_id, cc.customer_id, cc.external_reference, cc.amount_cents, cc.status, cc.due_at, cc.updated_at
from public.customer_charges cc
where cc.company_id = '11111111-1111-1111-1111-111111111111'::uuid
  and cc.external_reference = 'DUP-001';
