-- =============================================================================
--  09 Funciones que usan los flujos n8n de la Bandeja de comunicaciones (F1–F6)
--  Las llama el backend (rutas /api/n8n/*) con la credencial de servicio.
--
--  Origen: n8n_funciones_supabase.sql (F1 y F6, revisadas) + funciones nuevas de
--  F2, F3, F4 y compartidas, con la forma de respuesta que esperan los flujos.
--  Cambios respecto al archivo original:
--   · n8n_registrar_correo_nuevo reutiliza fn_registrar_comunicacion_n8n (08):
--     valida adjuntos y no duplica la nota de adjuntos omitidos en un reintento.
--   · n8n_registrar_respuesta_dependencia guarda el Message-ID de la respuesta en
--     el evento, y n8n_estado_correo lo usa para marcarla como ya procesada.
--   · Permisos: se revoca de PUBLIC y se concede a service_role solo si existe.
-- =============================================================================

-- ───────────── F1 · Consultar estado del correo ─────────────
create or replace function n8n_estado_correo(
  p_message_id text, p_asunto text, p_in_reply_to text, p_de_correo text)
returns table(ya_procesado boolean, comunicacion_id bigint, dependencia_id bigint,
              dependencia_nombre text, es_propio boolean)
language sql stable as $$
  select
    (exists (select 1 from comunicacion where message_id = p_message_id)
     or exists (select 1 from correo_sin_asociar where message_id = p_message_id)
     or exists (select 1 from comunicacion_evento where message_id = p_message_id and tipo = 'respuesta_dependencia')),
    fn_buscar_comunicacion_respondida(p_asunto, p_in_reply_to)::bigint,
    (select d.id from dependencia d where lower(d.correo_oficial) = lower(p_de_correo) and d.estado = 'activo' limit 1)::bigint,
    (select d.nombre from dependencia d where lower(d.correo_oficial) = lower(p_de_correo) and d.estado = 'activo' limit 1)::text,
    (lower(coalesce(p_de_correo, '')) = lower(coalesce(
       (select trim(both '"' from valor) from parametro where clave = 'buzon_archivo_central'), '')));
$$;

-- ───────────── F1 · Registrar rebote ─────────────
create or replace function n8n_registrar_rebote(p_ids text[], p_de text, p_asunto text)
returns table(asociados bigint, auditado boolean)
language plpgsql as $$
declare v_n bigint;
begin
  with ref as (
    select distinct e.comunicacion_id from comunicacion_evento e where e.message_id = any(coalesce(p_ids, '{}'))
  ), ins as (
    insert into comunicacion_evento (comunicacion_id, tipo, detalle)
    select ref.comunicacion_id, 'error_envio',
           jsonb_build_object('motivo', 'rebote', 'de', p_de, 'asunto', p_asunto)
    from ref
    returning comunicacion_id
  )
  select count(*) into v_n from ins;

  perform fn_auditar('error_flujo', 'n8n', 'F1 Correo entrante',
                     jsonb_build_object('motivo', 'rebote', 'de', p_de, 'asunto', p_asunto, 'citados', p_ids),
                     'error');
  return query select v_n, true;
end $$;

-- ───────────── F1 · A · Registrar respuesta de la dependencia ─────────────
-- Si la transición no es válida la base lanza RN-AC-09 y el flujo manda el correo a "sin asociar".
create or replace function n8n_registrar_respuesta_dependencia(
  p_comunicacion_id bigint, p_de_correo text, p_asunto text, p_cuerpo text,
  p_message_id text, p_recibido_en text, p_archivo_ids uuid[], p_adjuntos_omitidos jsonb)
returns table(id bigint, consecutivo text, estado text)
language plpgsql as $$
#variable_conflict use_column
declare
  v_evento bigint;
begin
  update comunicacion set estado = 'respondida_dependencia' where comunicacion.id = p_comunicacion_id;
  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id using errcode = '23503';
  end if;

  select max(e.id) into v_evento from comunicacion_evento e
   where e.comunicacion_id = p_comunicacion_id and e.tipo = 'respuesta_dependencia';

  update comunicacion_evento
     set message_id = p_message_id,
         detalle = coalesce(detalle, '{}'::jsonb) || jsonb_build_object(
           'de_correo', p_de_correo, 'asunto', p_asunto, 'cuerpo', p_cuerpo,
           'message_id_correo', p_message_id, 'recibido_en', p_recibido_en)
   where comunicacion_evento.id = v_evento;

  insert into comunicacion_adjunto (comunicacion_id, evento_id, archivo_id)
  select p_comunicacion_id, v_evento, a from unnest(coalesce(p_archivo_ids, '{}')) as a
  on conflict do nothing;

  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  select p_comunicacion_id, 'nota',
         jsonb_build_object('motivo', 'adjuntos_no_guardados', 'adjuntos', p_adjuntos_omitidos)
  where coalesce(p_adjuntos_omitidos, '[]'::jsonb) <> '[]'::jsonb;

  return query select c.id, c.consecutivo, c.estado::text from comunicacion c where c.id = p_comunicacion_id;
end $$;

-- ───────────── F1 · B · Registrar correo nuevo ─────────────
create or replace function n8n_registrar_correo_nuevo(
  p_message_id text, p_de_nombre text, p_de_correo text, p_asunto text, p_cuerpo text,
  p_recibido_en timestamptz, p_in_reply_to text, p_archivo_ids uuid[], p_adjuntos_omitidos jsonb)
returns table(id bigint, consecutivo text)
language plpgsql as $$
declare r record;
begin
  select * into r from fn_registrar_comunicacion_n8n(p_message_id, p_de_nombre, p_de_correo, p_asunto, p_cuerpo,
                                                     p_recibido_en, p_in_reply_to, coalesce(p_archivo_ids, '{}'));
  if r.creada and coalesce(p_adjuntos_omitidos, '[]'::jsonb) <> '[]'::jsonb then
    insert into comunicacion_evento (comunicacion_id, tipo, detalle)
    values (r.comunicacion_id, 'nota', jsonb_build_object('motivo', 'adjuntos_no_guardados', 'adjuntos', p_adjuntos_omitidos));
  end if;
  return query select r.comunicacion_id, r.consecutivo;
end $$;

-- ───────────── F1 · Guardar sugerencia (nota) ─────────────
create or replace function n8n_guardar_sugerencia(p_comunicacion_id bigint, p_detalle jsonb)
returns table(id bigint)
language sql as $$
  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  select p_comunicacion_id, 'nota', p_detalle
  where p_detalle is not null
  returning id::bigint;
$$;

-- ───────────── F1 · Guardar en correos sin asociar ─────────────
create or replace function n8n_guardar_sin_asociar(
  p_message_id text, p_in_reply_to text, p_de_nombre text, p_de_correo text, p_asunto text,
  p_cuerpo text, p_recibido_en timestamptz, p_motivo text, p_posible_comunicacion_id bigint,
  p_adjuntos uuid[])
returns table(insertados bigint)
language sql as $$
  with i as (
    insert into correo_sin_asociar (message_id, in_reply_to, de_nombre, de_correo, asunto, cuerpo,
                                    recibido_en, motivo, posible_comunicacion_id, adjuntos)
    values (p_message_id, p_in_reply_to, p_de_nombre, p_de_correo, p_asunto, p_cuerpo,
            coalesce(p_recibido_en, now()), p_motivo, p_posible_comunicacion_id, coalesce(p_adjuntos, '{}'))
    on conflict (message_id) do nothing
    returning id
  )
  select count(*) from i;
$$;

-- ───────────── F1 · Registrar error del acuse ─────────────
create or replace function n8n_registrar_error_acuse(p_comunicacion_id bigint, p_error text)
returns table(id bigint)
language sql as $$
  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  values (p_comunicacion_id, 'error_envio',
          jsonb_build_object('flujo', 'F1', 'destino', 'acuse_recibo', 'error', p_error))
  returning id::bigint;
$$;

-- ───────────── F2 · Leer comunicación y dependencia ─────────────
-- Si no existe la comunicación: {"id": null}. dep_* = dependencia indicada o, si es null, la de la comunicación.
create or replace function n8n_leer_remision(p_comunicacion_id bigint, p_dependencia_id bigint default null)
returns jsonb
language sql stable as $$
  select coalesce((
    select jsonb_build_object(
      'id', c.id, 'tipo', c.tipo, 'estado', c.estado, 'consecutivo', c.consecutivo, 'asunto', c.asunto,
      'dep_id', d.id, 'dependencia', d.nombre, 'dep_estado', d.estado, 'correo_oficial', d.correo_oficial,
      'plazo_defecto', fn_parametro_entero('plazo_respuesta_dias_habiles'),
      'adjuntos', coalesce((select jsonb_agg(ad.archivo_id order by ad.id) from comunicacion_adjunto ad where ad.comunicacion_id = c.id), '[]'::jsonb))
    from comunicacion c
    left join dependencia d on d.id = coalesce(p_dependencia_id, c.dependencia_id)
    where c.id = p_comunicacion_id
  ), jsonb_build_object('id', null));
$$;

-- ───────────── F2 · Registrar remisión (tras enviar el correo) ─────────────
create or replace function n8n_remitir(
  p_usuario bigint, p_comunicacion_id bigint, p_dependencia_id bigint,
  p_plazo integer, p_message_id text, p_mensaje text)
returns jsonb
language plpgsql as $$
declare v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario);
  v := fn_remitir_comunicacion(p_comunicacion_id, p_dependencia_id, p_plazo, p_message_id, p_mensaje);
  return jsonb_build_object('id', v.id, 'consecutivo', v.consecutivo, 'estado', v.estado,
                            'dependencia_id', v.dependencia_id, 'fecha_limite', v.fecha_limite);
end $$;

-- ───────────── F2 · Registrar devolución (tras enviar el correo) ─────────────
-- Da un nuevo plazo (parámetro plazo_respuesta_dias_habiles) para que los recordatorios cuenten desde hoy.
create or replace function n8n_devolver(
  p_usuario bigint, p_comunicacion_id bigint, p_message_id text, p_dependencia_id bigint, p_mensaje text)
returns jsonb
language plpgsql as $$
declare v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario);
  if p_dependencia_id is not null
     and not exists (select 1 from comunicacion where id = p_comunicacion_id and dependencia_id = p_dependencia_id) then
    raise exception 'La comunicación % no está remitida a la dependencia %', p_comunicacion_id, p_dependencia_id using errcode = '22023';
  end if;
  v := fn_devolver_respuesta_usuario(p_usuario, p_comunicacion_id, p_mensaje, p_message_id);
  update comunicacion
     set fecha_limite = fn_sumar_dias_habiles(current_date, coalesce(fn_parametro_entero('plazo_respuesta_dias_habiles'), 5)),
         n_recordatorios = 0, por_escalar = false, ultimo_recordatorio_en = null
   where id = v.id
  returning * into v;
  return jsonb_build_object('id', v.id, 'consecutivo', v.consecutivo, 'estado', v.estado,
                            'dependencia_id', v.dependencia_id, 'fecha_limite', v.fecha_limite);
end $$;

-- ───────────── F3 · Leer comunicación de entrada ─────────────
-- adjuntos: [{archivo_id, de_dependencia}] — de_dependencia = vino en la respuesta de la dependencia.
create or replace function n8n_leer_entrada(p_comunicacion_id bigint)
returns jsonb
language sql stable as $$
  select coalesce((
    select jsonb_build_object(
      'id', c.id, 'tipo', c.tipo, 'estado', c.estado, 'consecutivo', c.consecutivo, 'asunto', c.asunto,
      'remitente_nombre', c.remitente_nombre, 'remitente_correo', c.remitente_correo,
      'adjuntos', coalesce((
        select jsonb_agg(jsonb_build_object('archivo_id', ad.archivo_id,
                                            'de_dependencia', coalesce(ev.tipo = 'respuesta_dependencia', false))
                         order by ad.id)
        from comunicacion_adjunto ad
        left join comunicacion_evento ev on ev.id = ad.evento_id
        where ad.comunicacion_id = c.id), '[]'::jsonb))
    from comunicacion c where c.id = p_comunicacion_id
  ), jsonb_build_object('id', null));
$$;

-- ───────────── F3 · Registrar salida y cerrar la entrada (tras enviar el correo) ─────────────
create or replace function n8n_responder(
  p_usuario bigint, p_entrada_id bigint, p_asunto text, p_cuerpo text, p_message_id text, p_archivos uuid[])
returns jsonb
language plpgsql as $$
declare
  s comunicacion;
  v_ajenos uuid[];
begin
  select array_agg(a) into v_ajenos
  from unnest(coalesce(p_archivos, '{}')) a
  where not exists (select 1 from comunicacion_adjunto ad where ad.comunicacion_id = p_entrada_id and ad.archivo_id = a);
  if v_ajenos is not null then
    raise exception 'Archivos que no son adjuntos de la comunicación %: %', p_entrada_id, array_to_string(v_ajenos, ', ')
      using errcode = '22023';
  end if;

  s := fn_responder_remitente_usuario(p_usuario, p_entrada_id, p_asunto, p_cuerpo, p_message_id);

  insert into comunicacion_adjunto (comunicacion_id, archivo_id)
  select s.id, a from unnest(coalesce(p_archivos, '{}')) a
  on conflict do nothing;

  return jsonb_build_object('id', s.id, 'consecutivo', s.consecutivo, 'estado', s.estado,
                            'entrada_id', p_entrada_id, 'adjuntos', coalesce(array_length(p_archivos, 1), 0));
end $$;

-- ───────────── Compartida F2/F3/F4 · Error de envío ─────────────
create or replace function n8n_registrar_error_envio(
  p_usuario bigint, p_comunicaciones bigint[], p_dependencia bigint, p_detalle jsonb)
returns jsonb
language plpgsql as $$
declare v_n integer;
begin
  perform fn_set_usuario_actual(p_usuario);
  with ins as (
    insert into comunicacion_evento (comunicacion_id, tipo, dependencia_id, usuario_id, detalle)
    select c.id, 'error_envio', p_dependencia, p_usuario, coalesce(p_detalle, '{}'::jsonb)
    from comunicacion c where c.id = any(coalesce(p_comunicaciones, '{}'))
    returning 1
  )
  select count(*) into v_n from ins;

  perform fn_auditar('error_envio', 'n8n', coalesce(p_detalle ->> 'flujo', 'n8n'),
                     coalesce(p_detalle, '{}'::jsonb) || jsonb_build_object('comunicaciones', p_comunicaciones), 'error');
  return jsonb_build_object('registrados', v_n);
end $$;

-- ───────────── Compartida F2/F3 · Auditar (p. ej. enviado pero no registrado) ─────────────
create or replace function n8n_auditar(p_flujo text, p_detalle jsonb)
returns jsonb
language plpgsql as $$
begin
  perform fn_auditar('error_flujo', 'n8n', p_flujo, coalesce(p_detalle, '{}'::jsonb), 'error');
  return jsonb_build_object('ok', true);
end $$;

-- ───────────── F6 · Registrar error de un flujo en la auditoría ─────────────
create or replace function n8n_auditar_error_flujo(
  p_flujo text, p_ejecucion text, p_nodo text, p_mensaje text, p_url text)
returns boolean
language plpgsql as $$
begin
  perform fn_auditar('error_flujo', 'n8n', p_flujo,
                     jsonb_build_object('ejecucion', p_ejecucion, 'nodo', p_nodo, 'error', p_mensaje, 'url', p_url),
                     'error');
  return true;
end $$;

-- ───────────── F4 · ¿Hoy es día hábil? ─────────────
create or replace function n8n_es_dia_habil()
returns jsonb
language sql stable as $$
  select jsonb_build_object('habil', fn_es_dia_habil(current_date));
$$;

-- ───────────── F4 · Pendientes por dependencia (una fila por dependencia) ─────────────
create or replace function n8n_recordatorios_pendientes()
returns table(dependencia_id bigint, nombre text, correo_oficial text, pendientes jsonb)
language sql stable as $$
  select d.id, d.nombre, d.correo_oficial,
         jsonb_agg(jsonb_build_object('id', r.comunicacion_id, 'consecutivo', r.consecutivo, 'asunto', r.asunto,
                                      'fecha_limite', r.fecha_limite, 'dias_vencida', r.dias_vencida)
                   order by r.fecha_limite)
  from fn_comunicaciones_a_recordar() r
  join dependencia d on d.id = r.dependencia_id
  group by d.id, d.nombre, d.correo_oficial
  order by d.nombre;
$$;

-- ───────────── F4 · Registrar recordatorios enviados ─────────────
create or replace function n8n_registrar_recordatorios(p_ids bigint[], p_message_id text)
returns jsonb
language plpgsql as $$
declare
  v_id bigint;
  v_n integer := 0;
begin
  foreach v_id in array coalesce(p_ids, '{}') loop
    perform fn_registrar_recordatorio(v_id, p_message_id);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object(
    'registrados', v_n,
    'por_escalar', (select count(*) from comunicacion where id = any(coalesce(p_ids, '{}')) and por_escalar));
end $$;

-- ───────────── F4 · Resumen del día (una fila por comunicación activa) ─────────────
create or replace function n8n_resumen_dia()
returns table(buzon text, consecutivo text, estado text, vencida boolean, por_escalar boolean,
              dependencia text, dias_desde_recepcion integer)
language sql stable as $$
  select (select trim(both '"' from valor) from parametro where clave = 'buzon_archivo_central'),
         b.consecutivo, b.estado::text, b.vencida, b.por_escalar, b.dependencia, b.dias_desde_recepcion
  from v_bandeja_comunicaciones b
  where b.estado in ('nueva', 'remitida', 'respondida_dependencia', 'devuelta')
  order by b.fecha_recepcion;
$$;

-- ───────────── Permisos: solo la credencial de servicio (backend) ─────────────
do $$
declare
  f record;
  hay_service_role boolean := exists (select 1 from pg_roles where rolname = 'service_role');
begin
  for f in
    select p.oid::regprocedure as firma
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'n8n\_%'
  loop
    execute format('revoke execute on function %s from public', f.firma);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke execute on function %s from anon', f.firma);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke execute on function %s from authenticated', f.firma);
    end if;
    if hay_service_role then
      execute format('grant execute on function %s to service_role', f.firma);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
