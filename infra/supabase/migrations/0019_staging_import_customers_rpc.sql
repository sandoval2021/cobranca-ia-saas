-- Hardening + safe staging import RPC for Lovable /importar-clientes

-- 1) Remove demo public-read policies in staging before handling real customer data.
drop policy if exists staging_demo_public_read_companies on public.companies;
drop policy if exists staging_demo_public_read_customers on public.customers;
drop policy if exists staging_demo_public_read_customer_charges on public.customer_charges;
drop policy if exists staging_demo_public_read_messages on public.messages;
drop policy if exists staging_demo_public_read_ai_messages on public.ai_messages;

-- 2) Revoke public write permissions (especially anon) on sensitive multi-tenant tables.
revoke insert, update, delete on table public.companies from anon, public;
revoke insert, update, delete on table public.customers from anon, public;
revoke insert, update, delete on table public.customer_charges from anon, public;
revoke insert, update, delete on table public.messages from anon, public;
revoke insert, update, delete on table public.ai_messages from anon, public;

create or replace function public.staging_import_customers_from_rows(
  p_company_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_is_super_admin boolean := false;
  v_allowed boolean := false;
  v_row_count integer;
  v_item jsonb;
  v_index integer := 0;

  v_imported integer := 0;
  v_updated integer := 0;
  v_charges_created integer := 0;
  v_duplicates integer := 0;
  v_errors integer := 0;

  v_rows_result jsonb := '[]'::jsonb;

  v_whatsapp_raw text;
  v_whatsapp_clean text;
  v_customer_name text;
  v_external_code text;
  v_external_customer_code text;
  v_service_name text;
  v_situation text;
  v_amount_cents integer;
  v_expires_at date;
  v_due_day smallint;

  v_customer_id uuid;
  v_existing_customer_id uuid;
  v_existing_charge_id uuid;
  v_charge_id uuid;
  v_external_reference text;
  v_status charge_status;
  v_row_result jsonb;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Usuário não autenticado. Faça login para importar clientes.' using errcode = '42501';
  end if;

  select public.current_user_is_super_admin() into v_is_super_admin;

  if p_company_id is null then
    raise exception 'company_id inválido: informe uma empresa válida.' using errcode = '22023';
  end if;

  if not exists (select 1 from public.companies c where c.id = p_company_id) then
    raise exception 'company_id inválido: empresa não encontrada.' using errcode = '22023';
  end if;

  select (
    v_is_super_admin
    or p_company_id in (select public.current_user_company_ids())
  ) into v_allowed;

  if coalesce(v_allowed, false) is not true then
    raise exception 'Sem permissão para importar dados para esta empresa.' using errcode = '42501';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'Formato inválido: p_rows deve ser um array JSON.' using errcode = '22023';
  end if;

  v_row_count := jsonb_array_length(p_rows);

  if v_row_count = 0 then
    raise exception 'Nenhuma linha para importar: p_rows está vazio.' using errcode = '22023';
  end if;

  if v_row_count > 1000 then
    raise exception 'Limite excedido: envie no máximo 1000 linhas por importação.' using errcode = '22023';
  end if;

  for v_item in select value from jsonb_array_elements(p_rows)
  loop
    begin
      v_index := v_index + 1;
      v_customer_id := null;
      v_charge_id := null;
      v_existing_customer_id := null;
      v_existing_charge_id := null;

      v_whatsapp_raw := nullif(btrim(coalesce(v_item->>'whatsapp_e164', '')), '');
      v_customer_name := nullif(btrim(coalesce(v_item->>'customer_name', '')), '');
      v_external_code := nullif(btrim(coalesce(v_item->>'external_code', '')), '');
      v_external_customer_code := nullif(btrim(coalesce(v_item->>'external_customer_code', '')), '');
      v_service_name := nullif(btrim(coalesce(v_item->>'service_name', '')), '');
      v_situation := nullif(btrim(coalesce(v_item->>'situation', '')), '');

      if v_whatsapp_raw is null then
        v_rows_result := v_rows_result || jsonb_build_array(jsonb_build_object(
          'index', v_index,
          'status', 'duplicate',
          'message', 'Linha ignorada: whatsapp_e164 ausente.'
        ));
        v_duplicates := v_duplicates + 1;
        continue;
      end if;

      v_whatsapp_clean := regexp_replace(v_whatsapp_raw, '[^0-9+]', '', 'g');
      if left(v_whatsapp_clean, 1) <> '+' then
        v_whatsapp_clean := '+' || regexp_replace(v_whatsapp_clean, '[^0-9]', '', 'g');
      else
        v_whatsapp_clean := '+' || regexp_replace(substr(v_whatsapp_clean, 2), '[^0-9]', '', 'g');
      end if;

      if length(regexp_replace(v_whatsapp_clean, '[^0-9]', '', 'g')) < 10 then
        v_rows_result := v_rows_result || jsonb_build_array(jsonb_build_object(
          'index', v_index,
          'status', 'error',
          'message', 'Telefone inválido após normalização.'
        ));
        v_errors := v_errors + 1;
        continue;
      end if;

      if v_customer_name is null then
        v_customer_name := regexp_replace(v_whatsapp_clean, '[^0-9]', '', 'g');
      end if;

      if (v_item ? 'amount_cents') and nullif(v_item->>'amount_cents', '') is not null then
        v_amount_cents := (v_item->>'amount_cents')::integer;
      else
        v_amount_cents := 0;
      end if;

      if v_amount_cents < 0 then
        v_amount_cents := 0;
      end if;

      if nullif(v_item->>'expires_at', '') is not null then
        v_expires_at := (v_item->>'expires_at')::date;
      else
        v_expires_at := null;
      end if;

      v_due_day := coalesce(extract(day from v_expires_at)::smallint, 1::smallint);

      if lower(coalesce(v_situation, '')) in ('ativo', 'em dia', 'ok', 'adimplente') then
        v_status := 'aprovado';
      elsif lower(coalesce(v_situation, '')) in ('cancelado', 'canceled') then
        v_status := 'cancelado';
      elsif lower(coalesce(v_situation, '')) in ('expirado', 'vencido') then
        v_status := 'expirado';
      elsif lower(coalesce(v_situation, '')) in ('falhou', 'erro', 'rejeitado') then
        v_status := 'falhou';
      else
        v_status := 'pendente';
      end if;

      select c.id
      into v_existing_customer_id
      from public.customers c
      where c.company_id = p_company_id
        and c.whatsapp_e164 = v_whatsapp_clean
      limit 1;

      if v_existing_customer_id is null then
        insert into public.customers (
          company_id, name, whatsapp_e164, amount_cents, due_day, status, notes
        ) values (
          p_company_id,
          v_customer_name,
          v_whatsapp_clean,
          v_amount_cents,
          v_due_day,
          'em_dia',
          case
            when v_external_code is not null or v_external_customer_code is not null then
              concat('import external_code=', coalesce(v_external_code, ''), ', external_customer_code=', coalesce(v_external_customer_code, ''))
            else null
          end
        )
        returning id into v_customer_id;

        v_imported := v_imported + 1;

        v_row_result := jsonb_build_object(
          'index', v_index,
          'status', 'imported',
          'message', 'Cliente importado com sucesso.',
          'customer_id', v_customer_id
        );
      else
        update public.customers c
        set
          name = coalesce(nullif(v_customer_name, ''), c.name),
          amount_cents = case when v_amount_cents > 0 then v_amount_cents else c.amount_cents end,
          due_day = case when v_due_day between 1 and 31 then v_due_day else c.due_day end,
          updated_at = now()
        where c.id = v_existing_customer_id;

        v_customer_id := v_existing_customer_id;
        v_updated := v_updated + 1;

        v_row_result := jsonb_build_object(
          'index', v_index,
          'status', 'updated',
          'message', 'Cliente já existia e foi atualizado.',
          'customer_id', v_customer_id
        );
      end if;

      if v_service_name is not null or v_expires_at is not null or v_amount_cents > 0 or v_situation is not null then
        v_external_reference := coalesce(
          nullif(v_external_code, ''),
          nullif(v_external_customer_code, ''),
          'import-' || v_customer_id::text || '-' || v_index::text
        );

        select cc.id into v_existing_charge_id
        from public.customer_charges cc
        where cc.company_id = p_company_id
          and cc.external_reference = v_external_reference
        limit 1;

        if v_existing_charge_id is null then
          insert into public.customer_charges (
            company_id, customer_id, external_reference,
            amount_cents, platform_fee_cents, provider_fee_cents, estimated_net_cents,
            status, due_at
          ) values (
            p_company_id,
            v_customer_id,
            v_external_reference,
            greatest(v_amount_cents, 0),
            0,
            0,
            greatest(v_amount_cents, 0),
            v_status,
            case when v_expires_at is not null then (v_expires_at::timestamp at time zone 'UTC') else null end
          )
          returning id into v_charge_id;

          v_charges_created := v_charges_created + 1;
        else
          update public.customer_charges cc
          set
            customer_id = v_customer_id,
            amount_cents = case when v_amount_cents > 0 then v_amount_cents else cc.amount_cents end,
            estimated_net_cents = case when v_amount_cents > 0 then v_amount_cents else cc.estimated_net_cents end,
            status = v_status,
            due_at = coalesce(case when v_expires_at is not null then (v_expires_at::timestamp at time zone 'UTC') else null end, cc.due_at),
            updated_at = now()
          where cc.id = v_existing_charge_id
          returning cc.id into v_charge_id;
        end if;

        v_row_result := v_row_result || jsonb_build_object('charge_id', v_charge_id);
      end if;

      v_rows_result := v_rows_result || jsonb_build_array(v_row_result);

    exception when others then
      v_errors := v_errors + 1;
      v_rows_result := v_rows_result || jsonb_build_array(jsonb_build_object(
        'index', v_index,
        'status', 'error',
        'message', 'Erro ao importar linha: ' || sqlerrm
      ));
    end;
  end loop;

  return jsonb_build_object(
    'imported', v_imported,
    'updated', v_updated,
    'charges_created', v_charges_created,
    'duplicates', v_duplicates,
    'errors', v_errors,
    'rows', v_rows_result
  );
end;
$$;

revoke all on function public.staging_import_customers_from_rows(uuid, jsonb) from public;
revoke all on function public.staging_import_customers_from_rows(uuid, jsonb) from anon;
grant execute on function public.staging_import_customers_from_rows(uuid, jsonb) to authenticated;
