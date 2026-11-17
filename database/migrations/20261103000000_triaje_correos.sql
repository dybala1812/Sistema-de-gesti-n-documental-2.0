-- =============================================================================
--  34 Triaje de correos en la Bandeja (D-32, SGD-099)
--
--  Cada correo de entrada tiene categoría, prioridad y resumen, y se marca como leído.
--   · categoria y prioridad las SUGIERE la IA de n8n F1 (triaje_origen = 'ia'): no cambian el
--     estado ni la dependencia (D-07, RN-AC-13). Una persona puede corregirlas desde la Bandeja
--     (triaje_origen = 'manual') y desde entonces n8n ya no las pisa.
--   · No leído = correo de entrada (tipo ENT, origen correo) con leido_en vacío. Es de la Bandeja,
--     no de cada persona. Los registros históricos y manuales no cuentan como no leídos.
--   · Los cambios quedan en la auditoría (trigger de comunicacion); los intentos sin permiso, también.
-- =============================================================================

alter table comunicacion
  add column categoria     text check (categoria in ('urgente', 'academico', 'administrativo', 'promociones', 'otros')),
  add column prioridad     text check (prioridad in ('alta', 'media', 'baja')),
  add column resumen       text,
  add column triaje_origen text check (triaje_origen in ('ia', 'manual')),
  add column leido_en      timestamptz,
  add column leido_por     bigint references usuario(id);

create index comunicacion_triaje_idx on comunicacion (categoria, prioridad);
create index comunicacion_no_leidas_idx on comunicacion (fecha_recepcion desc)
  where leido_en is null and tipo = 'ENT' and origen = 'correo';

-- Valores permitidos, con el mensaje que el formulario y n8n entienden.
create or replace function fn_triaje_validar(p_categoria text, p_prioridad text)
returns void
language plpgsql immutable
as $$
begin
  if p_categoria is not null and p_categoria not in ('urgente', 'academico', 'administrativo', 'promociones', 'otros') then
    raise exception '[campo:categoria|tipo:lista] La categoría debe ser urgente, academico, administrativo, promociones u otros'
      using errcode = '22023';
  end if;
  if p_prioridad is not null and p_prioridad not in ('alta', 'media', 'baja') then
    raise exception '[campo:prioridad|tipo:lista] La prioridad debe ser alta, media o baja'
      using errcode = '22023';
  end if;
end $$;

-- Marca como leído o no leído y reclasifica. Reclasificar deja el origen en 'manual'.
create or replace function fn_triaje_aplicar(p_id bigint, p_leido boolean, p_categoria text, p_prioridad text, p_usuario_id bigint)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  perform fn_triaje_validar(p_categoria, p_prioridad);
  if p_leido is null and p_categoria is null and p_prioridad is null then
    raise exception '[campo:leido|tipo:obligatorio] Indique leido, categoria o prioridad' using errcode = '22023';
  end if;

  update comunicacion
     set categoria     = coalesce(p_categoria, categoria),
         prioridad     = coalesce(p_prioridad, prioridad),
         triaje_origen = case when p_categoria is not null or p_prioridad is not null then 'manual' else triaje_origen end,
         leido_en      = case when p_leido is true then coalesce(leido_en, now()) when p_leido is false then null else leido_en end,
         leido_por     = case when p_leido is true then coalesce(leido_por, p_usuario_id) when p_leido is false then null else leido_por end
   where id = p_id
   returning * into v;

  if not found then
    raise exception '[campo:id|tipo:existente] La comunicación % no existe', p_id using errcode = '22023';
  end if;
  return v;
end $$;

-- Desde la Bandeja: exige comunicaciones.gestionar y audita el intento denegado.
create or replace function fn_comunicacion_triaje(
  p_usuario_id bigint, p_id bigint, p_leido boolean default null, p_categoria text default null, p_prioridad text default null)
returns jsonb
language plpgsql
as $$
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'comunicaciones.gestionar', 'actualizar', 'comunicacion', p_id::text) then
    return jsonb_build_object('denegado', true, 'funcion', 'comunicaciones.gestionar');
  end if;
  perform fn_triaje_aplicar(p_id, p_leido, p_categoria, p_prioridad, p_usuario_id);
  return jsonb_build_object('id', p_id);
end $$;

-- ── APIs para n8n ───────────────────────────────────────────────────────────

-- F1: guarda lo que sugirió la IA. Idempotente; nunca pisa lo que corrigió una persona.
create or replace function n8n_guardar_triaje(p_comunicacion_id bigint, p_categoria text, p_prioridad text, p_resumen text)
returns table(id bigint)
language plpgsql
as $$
begin
  perform fn_triaje_validar(p_categoria, p_prioridad);
  return query
    update comunicacion c
       set categoria     = p_categoria,
           prioridad     = p_prioridad,
           resumen       = left(p_resumen, 500),
           triaje_origen = 'ia'
     where c.id = p_comunicacion_id
       and c.triaje_origen is distinct from 'manual'
     returning c.id::bigint;
end $$;

-- Lo que devuelven las APIs de triaje por cada correo (sin el cuerpo).
create or replace function fn_triaje_fila(c comunicacion)
returns jsonb
language sql stable
as $$
  select jsonb_build_object(
    'id', c.id, 'consecutivo', c.consecutivo, 'estado', c.estado, 'fecha', c.fecha_recepcion,
    'remitente_nombre', c.remitente_nombre, 'remitente_correo', c.remitente_correo, 'asunto', c.asunto,
    'resumen', c.resumen, 'categoria', c.categoria, 'prioridad', c.prioridad, 'triaje_origen', c.triaje_origen,
    'leido', c.leido_en is not null, 'dependencia_id', c.dependencia_id)
$$;

-- F7 · GET /correos: correos de entrada, del más reciente al más antiguo.
create or replace function n8n_triaje_listar(
  p_categoria text default null, p_prioridad text default null, p_leido boolean default null, p_urgentes boolean default null,
  p_q text default null, p_limite integer default 50, p_pagina integer default 1)
returns jsonb
language plpgsql stable
as $$
declare
  v_limite int := least(greatest(coalesce(p_limite, 50), 1), 200);
  v_pagina int := greatest(coalesce(p_pagina, 1), 1);
  v_q text := nullif(trim(p_q), '');
  v_total bigint;
  v_filas jsonb;
begin
  perform fn_triaje_validar(p_categoria, p_prioridad);
  with base as (
    select c.* from comunicacion c
     where c.tipo = 'ENT' and c.origen = 'correo' and c.estado <> 'anulada'
       and (p_categoria is null or c.categoria = p_categoria)
       and (p_prioridad is null or c.prioridad = p_prioridad)
       and (p_leido is null or (c.leido_en is not null) = p_leido)
       and (p_urgentes is not true or c.categoria = 'urgente' or c.prioridad = 'alta')
       and (v_q is null or c.asunto ilike '%' || v_q || '%' or c.remitente_nombre ilike '%' || v_q || '%' or c.remitente_correo ilike '%' || v_q || '%')
  ), pagina as (
    select * from base order by fecha_recepcion desc, id desc limit v_limite offset (v_pagina - 1) * v_limite
  )
  select (select count(*) from base), coalesce((select jsonb_agg(fn_triaje_fila(p::comunicacion)) from pagina p), '[]'::jsonb)
    into v_total, v_filas;
  return jsonb_build_object('filas', v_filas, 'total', v_total, 'pagina', v_pagina, 'limite', v_limite);
end $$;

-- F7 · GET /estadisticas: contadores de los correos de entrada que no están anulados.
create or replace function n8n_triaje_estadisticas()
returns jsonb
language sql stable
as $$
  select jsonb_build_object(
    'total', count(*),
    'no_leidos', count(*) filter (where leido_en is null),
    'urgentes', count(*) filter (where categoria = 'urgente' or prioridad = 'alta'),
    'por_categoria', jsonb_build_object(
      'urgente', count(*) filter (where categoria = 'urgente'),
      'academico', count(*) filter (where categoria = 'academico'),
      'administrativo', count(*) filter (where categoria = 'administrativo'),
      'promociones', count(*) filter (where categoria = 'promociones'),
      'otros', count(*) filter (where categoria = 'otros'),
      'sin_clasificar', count(*) filter (where categoria is null)),
    'por_prioridad', jsonb_build_object(
      'alta', count(*) filter (where prioridad = 'alta'),
      'media', count(*) filter (where prioridad = 'media'),
      'baja', count(*) filter (where prioridad = 'baja'),
      'sin_prioridad', count(*) filter (where prioridad is null)))
  from comunicacion
  where tipo = 'ENT' and origen = 'correo' and estado <> 'anulada'
$$;

-- F7 · PATCH /correos/:id: lo hace el servicio n8n (leido_por queda vacío).
create or replace function n8n_triaje_actualizar(p_id bigint, p_leido boolean default null, p_categoria text default null, p_prioridad text default null)
returns jsonb
language sql
as $$
  select fn_triaje_fila(fn_triaje_aplicar(p_id, p_leido, p_categoria, p_prioridad, null))
$$;

-- F5 y F6 leían estas dos tablas con el nodo de Supabase (D-19, I-21).
create or replace function n8n_leer_plantilla(p_codigo text)
returns table(codigo text, nombre text, asunto text, cuerpo text)
language sql stable
as $$
  select p.codigo, p.nombre, p.asunto, p.cuerpo from plantilla_correo p where p.codigo = p_codigo
$$;

create or replace function n8n_leer_parametro(p_clave text)
returns table(clave text, valor text)
language sql stable
as $$
  select p.clave, p.valor from parametro p where p.clave = p_clave
$$;

revoke execute on function fn_triaje_validar(text, text) from public;
revoke execute on function fn_triaje_aplicar(bigint, boolean, text, text, bigint) from public;
revoke execute on function fn_comunicacion_triaje(bigint, bigint, boolean, text, text) from public;
revoke execute on function n8n_guardar_triaje(bigint, text, text, text) from public;
revoke execute on function fn_triaje_fila(comunicacion) from public;
revoke execute on function n8n_triaje_listar(text, text, boolean, boolean, text, integer, integer) from public;
revoke execute on function n8n_triaje_estadisticas() from public;
revoke execute on function n8n_triaje_actualizar(bigint, boolean, text, text) from public;
revoke execute on function n8n_leer_plantilla(text) from public;
revoke execute on function n8n_leer_parametro(text) from public;
