-- =============================================================================
--  15 Varias respuestas de la dependencia a una misma comunicación
--
--  Problema: n8n_registrar_respuesta_dependencia (migración 09) asumía una sola
--  respuesta. Con la primera, el cambio de estado crea el evento
--  "respuesta_dependencia" y se le pone el correo. Con la segunda (otra persona de
--  la dependencia, o un complemento) el estado ya es "respondida_dependencia": no
--  se crea evento, el adjunto se cuelga del evento del primer correo y el texto
--  del segundo se pierde.
--
--  Solución: cada correo de respuesta es su propio evento, con su remitente, texto
--  y adjuntos. Idempotente por Message-ID (RN 12): si F1 reintenta el mismo correo,
--  no se duplica.
-- =============================================================================

create or replace function n8n_registrar_respuesta_dependencia(
  p_comunicacion_id bigint, p_de_correo text, p_asunto text, p_cuerpo text,
  p_message_id text, p_recibido_en text, p_archivo_ids uuid[], p_adjuntos_omitidos jsonb)
returns table(id bigint, consecutivo text, estado text)
language plpgsql as $$
#variable_conflict use_column
declare
  v_com comunicacion;
  v_evento bigint;
  v_detalle jsonb := jsonb_build_object(
    'de_correo', p_de_correo, 'asunto', p_asunto, 'cuerpo', p_cuerpo,
    'message_id_correo', p_message_id, 'recibido_en', p_recibido_en);
begin
  select * into v_com from comunicacion c where c.id = p_comunicacion_id for update;
  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id using errcode = '23503';
  end if;

  -- El mismo correo ya se registró (reintento de F1): no se duplica.
  if nullif(trim(p_message_id), '') is not null then
    select e.id into v_evento from comunicacion_evento e
     where e.comunicacion_id = p_comunicacion_id and e.tipo = 'respuesta_dependencia'
       and e.message_id = p_message_id
     limit 1;
  end if;

  if v_evento is null then
    if v_com.estado = 'respondida_dependencia' then
      -- Ya había respuesta: este correo es una respuesta más (sin cambio de estado).
      insert into comunicacion_evento (comunicacion_id, tipo, estado_anterior, estado_nuevo, dependencia_id, message_id, detalle)
      values (p_comunicacion_id, 'respuesta_dependencia', v_com.estado, v_com.estado, v_com.dependencia_id,
              p_message_id, v_detalle || jsonb_build_object('respuesta_adicional', true))
      returning comunicacion_evento.id into v_evento;
    else
      -- Primera respuesta: el trigger valida la transición (RN-AC-09) y crea el evento.
      update comunicacion set estado = 'respondida_dependencia' where comunicacion.id = p_comunicacion_id;
      select max(e.id) into v_evento from comunicacion_evento e
       where e.comunicacion_id = p_comunicacion_id and e.tipo = 'respuesta_dependencia';
      update comunicacion_evento
         set message_id = p_message_id,
             detalle = coalesce(detalle, '{}'::jsonb) || v_detalle
       where comunicacion_evento.id = v_evento;
    end if;
  end if;

  insert into comunicacion_adjunto (comunicacion_id, evento_id, archivo_id)
  select p_comunicacion_id, v_evento, a from unnest(coalesce(p_archivo_ids, '{}')) as a
  on conflict do nothing;

  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  select p_comunicacion_id, 'nota',
         jsonb_build_object('motivo', 'adjuntos_no_guardados', 'adjuntos', p_adjuntos_omitidos)
  where coalesce(p_adjuntos_omitidos, '[]'::jsonb) <> '[]'::jsonb;

  return query select c.id, c.consecutivo, c.estado::text from comunicacion c where c.id = p_comunicacion_id;
end $$;

-- Solo el backend (service_role) puede llamarla.
revoke execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) to service_role';
  end if;
end $$;

notify pgrst, 'reload schema';
