-- =============================================================================
--  08 Registro de comunicaciones entrantes desde n8n (F1 · RF-AC-015)
--  Usado por POST /api/n8n/comunicaciones del backend.
-- =============================================================================

-- Registra un correo entrante con sus adjuntos en UNA transacción.
-- Idempotente por Message-ID (RNF-AC-04): si el correo ya existe devuelve la
-- comunicación existente (creada = false) y solo agrega los adjuntos que falten,
-- así un reintento de n8n nunca duplica nada.
-- Los adjuntos son ids de la tabla `archivo` (subidos antes con POST /api/archivos).
create or replace function fn_registrar_comunicacion_n8n(
  p_message_id       text,
  p_remitente_nombre text,
  p_remitente_correo text,
  p_asunto           text,
  p_cuerpo           text,
  p_recibido_en      timestamptz,
  p_in_reply_to      text default null,
  p_adjuntos         uuid[] default '{}'
)
returns table (comunicacion_id bigint, consecutivo text, estado estado_comunicacion, creada boolean, adjuntos integer)
language plpgsql
as $$
#variable_conflict use_column
declare
  v_existia boolean;
  v comunicacion;
  v_faltantes uuid[];
begin
  if coalesce(trim(p_message_id), '') = '' then
    raise exception 'message_id es obligatorio' using errcode = '22023';
  end if;

  -- Los adjuntos deben existir en `archivo` (los registra el backend al subirlos).
  select array_agg(a) into v_faltantes
  from unnest(coalesce(p_adjuntos, '{}')) a
  where not exists (select 1 from archivo where id = a);
  if v_faltantes is not null then
    raise exception 'Adjuntos inexistentes: %', array_to_string(v_faltantes, ', ') using errcode = '23503';
  end if;

  select exists (select 1 from comunicacion where message_id = p_message_id) into v_existia;

  v := fn_registrar_correo_entrante(p_message_id, p_remitente_nombre, p_remitente_correo,
                                    p_asunto, p_cuerpo, coalesce(p_recibido_en, now()), p_in_reply_to);

  insert into comunicacion_adjunto (comunicacion_id, archivo_id)
  select v.id, a from unnest(coalesce(p_adjuntos, '{}')) a
  on conflict (comunicacion_id, archivo_id) do nothing;

  return query
  select v.id, v.consecutivo, v.estado, not v_existia,
         (select count(*)::integer from comunicacion_adjunto ad where ad.comunicacion_id = v.id);
end;
$$;

-- Sin acceso desde la API pública. En PostgreSQL EXECUTE se concede a PUBLIC por
-- defecto (y anon/authenticated lo heredan), por eso se revoca de PUBLIC y se
-- concede solo a service_role (la credencial del backend).
revoke execute on function fn_registrar_comunicacion_n8n(text, text, text, text, text, timestamptz, text, uuid[]) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_registrar_comunicacion_n8n(text, text, text, text, text, timestamptz, text, uuid[]) to service_role';
  end if;
end $$;
