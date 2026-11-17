-- =============================================================================
--  38 Evento de acuse de recibo desde n8n F1 (RF-AC-015, D-19, D-31)
--
--  F1 envía el acuse de recibo por SMTP a quien escribió al buzón. Antes el evento lo insertaba
--  un nodo de Supabase; sin Supabase (D-31) se perdió y el historial de la comunicación no mostraba
--  el acuse. Ahora F1 llama a POST /api/n8n/correos/acuse, que usa esta función.
--   · Solo para comunicaciones de entrada (ENT).
--   · Idempotente: el mismo Message-ID no crea dos eventos.
--   · El trigger comunicacion_evento_ultimo_envio guarda el Message-ID en comunicacion.ultimo_envio_id.
--  Si el acuse no sale, F1 usa la función que ya existía: n8n_registrar_error_acuse.
-- =============================================================================

create or replace function n8n_registrar_acuse(p_comunicacion_id bigint, p_message_id text)
returns table(id bigint)
language plpgsql
as $$
declare
  v_tipo tipo_comunicacion;
  v_id   bigint;
begin
  if coalesce(trim(p_message_id), '') = '' then
    raise exception '[campo:message_id|tipo:obligatorio] message_id es obligatorio' using errcode = '22023';
  end if;
  select c.tipo into v_tipo from comunicacion c where c.id = p_comunicacion_id;
  if not found then
    raise exception '[campo:comunicacion_id|tipo:existente] La comunicación % no existe', p_comunicacion_id using errcode = '22023';
  end if;
  if v_tipo <> 'ENT' then
    raise exception '[campo:comunicacion_id|tipo:tipo] El acuse de recibo solo aplica a comunicaciones de entrada' using errcode = '22023';
  end if;

  select e.id into v_id
    from comunicacion_evento e
   where e.comunicacion_id = p_comunicacion_id
     and e.tipo = 'acuse_recibo'
     and e.message_id = trim(p_message_id);

  if v_id is null then
    insert into comunicacion_evento (comunicacion_id, tipo, message_id, detalle)
    values (p_comunicacion_id, 'acuse_recibo', trim(p_message_id), jsonb_build_object('flujo', 'F1'))
    returning comunicacion_evento.id into v_id;
  end if;

  return query select v_id;
end $$;

revoke execute on function n8n_registrar_acuse(bigint, text) from public;
