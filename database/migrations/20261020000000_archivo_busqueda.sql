-- SGD-032 / RF-AC-013 / RF-AC-014: archivo navegable Dependencia → Año → Asunto y búsqueda avanzada.
--
--   - fn_alcance_consulta: permiso de consulta (audita el intento denegado) y dependencia a la que se
--     limita un usuario del perfil Dependencia (null = ve todas).
--   - fn_archivo_arbol: árbol con la cantidad de documentos clasificados por nodo. Incluye las
--     dependencias activas aunque aún no tengan documentos.
--   - fn_archivo_buscar: búsqueda paginada (20 por página) en documentos clasificados y comunicaciones,
--     por año, mes, día, dependencia, tipo, asunto, consecutivo, persona, código TRD y texto libre.
-- Documentos requieren documentos.consultar; comunicaciones, comunicaciones.consultar. Un usuario de
-- Dependencia solo ve lo de su dependencia (RF-AC-013).

create index if not exists documento_destinatario_trgm on documento using gin (destinatario gin_trgm_ops);
create index if not exists comunicacion_destinatario_trgm on comunicacion using gin (destinatario_nombre gin_trgm_ops);

create or replace function fn_alcance_consulta(
  p_usuario_id bigint, p_funcion text, p_recurso_tipo text, p_recurso_id text default null,
  out permitido boolean, out dependencia_id bigint)
language plpgsql
as $$
begin
  perform fn_set_usuario_actual(p_usuario_id);
  permitido := fn_catalogo_autorizar(p_usuario_id, p_funcion, 'consultar', p_recurso_tipo, p_recurso_id);
  select case when u.perfil = 'dependencia' then coalesce(u.dependencia_id, -1) end into dependencia_id
    from usuario u where u.id = p_usuario_id;
end $$;

-- Texto del usuario como patrón ILIKE literal (sin comodines propios).
create or replace function fn_patron_contiene(p_texto text)
returns text
language sql immutable
as $$
  select '%' || replace(replace(replace(trim(p_texto), '\', '\\'), '%', '\%'), '_', '\_') || '%'
$$;

create or replace function fn_archivo_arbol(p_usuario_id bigint)
returns jsonb
language plpgsql
as $$
declare
  v_alcance record;
begin
  select * into v_alcance from fn_alcance_consulta(p_usuario_id, 'documentos.consultar', 'archivo');
  if not v_alcance.permitido then
    return jsonb_build_object('denegado', true, 'funcion', 'documentos.consultar');
  end if;

  return coalesce((
    with conteos as (
      select doc.dependencia_id, doc.anio::int as anio, doc.asunto_id, count(*)::int as n
        from documento doc
       where doc.estado = 'clasificado'
         and (v_alcance.dependencia_id is null or doc.dependencia_id = v_alcance.dependencia_id)
       group by 1, 2, 3
    )
    select jsonb_agg(jsonb_build_object(
             'dependencia_id', d.id, 'codigo', d.codigo, 'nombre', d.nombre,
             'total', coalesce((select sum(c.n) from conteos c where c.dependencia_id = d.id), 0),
             'anios', coalesce((
               select jsonb_agg(jsonb_build_object('anio', y.anio, 'total', y.total, 'asuntos', y.asuntos) order by y.anio desc)
                 from (select c.anio, sum(c.n)::int as total,
                              jsonb_agg(jsonb_build_object('asunto_id', a.id, 'nombre', a.nombre, 'trd', t.codigo, 'total', c.n)
                                        order by a.nombre) as asuntos
                         from conteos c
                         join asunto a on a.id = c.asunto_id
                         left join trd t on t.id = a.trd_id
                        where c.dependencia_id = d.id
                        group by c.anio) y), '[]'::jsonb))
           order by d.nombre)
      from dependencia d
     where (v_alcance.dependencia_id is null or d.id = v_alcance.dependencia_id)
       and (d.estado = 'activo' or exists (select 1 from conteos c where c.dependencia_id = d.id))
  ), '[]'::jsonb);
end $$;

create or replace function fn_archivo_buscar(
  p_usuario_id bigint, p_filtros jsonb default '{}'::jsonb, p_pagina integer default 1, p_limite integer default 20)
returns jsonb
language plpgsql
as $$
declare
  f jsonb := coalesce(p_filtros, '{}'::jsonb);
  v_scope bigint;   -- dependencia del usuario si es del perfil Dependencia (null = todas)
  v_alcance text := coalesce(nullif(trim(f ->> 'alcance'), ''), 'todo');
  v_incluir_docs boolean;
  v_incluir_coms boolean;
  v_anio int := nullif(f ->> 'anio', '')::int;
  v_mes int := nullif(f ->> 'mes', '')::int;
  v_dia int := nullif(f ->> 'dia', '')::int;
  v_dep bigint := nullif(f ->> 'dependencia_id', '')::bigint;
  v_asunto_id bigint := nullif(f ->> 'asunto_id', '')::bigint;
  v_tipo tipo_comunicacion;
  v_asunto text := nullif(trim(f ->> 'asunto'), '');
  v_consecutivo text := nullif(ltrim(trim(f ->> 'consecutivo'), '0'), '');
  v_persona text := nullif(trim(f ->> 'persona'), '');
  v_trd text := nullif(trim(f ->> 'trd'), '');
  v_texto text := nullif(trim(f ->> 'texto'), '');
  v_limite int := least(greatest(coalesce(p_limite, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_pagina, 1), 1) - 1) * least(greatest(coalesce(p_limite, 20), 1), 100);
begin
  if v_alcance not in ('todo', 'documentos', 'comunicaciones') then
    raise exception '[campo:alcance|tipo:lista] Alcance no válido: todo, documentos o comunicaciones' using errcode = '22023';
  end if;
  if v_mes is not null and v_mes not between 1 and 12 then
    raise exception '[campo:mes|tipo:rango] Mes no válido (1 a 12)' using errcode = '22023';
  end if;
  if v_dia is not null and v_dia not between 1 and 31 then
    raise exception '[campo:dia|tipo:rango] Día no válido (1 a 31)' using errcode = '22023';
  end if;
  if nullif(trim(f ->> 'tipo'), '') is not null then
    v_tipo := fn_historico_tipo(f ->> 'tipo');
    if v_tipo is null then
      raise exception '[campo:tipo|tipo:lista] Tipo no válido: entrada, salida o interno' using errcode = '22023';
    end if;
  end if;

  -- Cada parte exige su permiso; sin ninguno, la búsqueda se niega y queda auditada.
  perform fn_set_usuario_actual(p_usuario_id);
  v_incluir_docs := v_alcance in ('todo', 'documentos') and fn_tiene_permiso(p_usuario_id, 'documentos.consultar');
  v_incluir_coms := v_alcance in ('todo', 'comunicaciones') and fn_tiene_permiso(p_usuario_id, 'comunicaciones.consultar');
  if not v_incluir_docs and not v_incluir_coms then
    perform fn_catalogo_autorizar(p_usuario_id,
      case when v_alcance = 'comunicaciones' then 'comunicaciones.consultar' else 'documentos.consultar' end,
      'consultar', 'busqueda', null);
    return jsonb_build_object('denegado', true,
      'funcion', case when v_alcance = 'comunicaciones' then 'comunicaciones.consultar' else 'documentos.consultar' end);
  end if;
  -- Las comunicaciones no tienen asunto ni TRD: con esos filtros solo se buscan documentos.
  v_incluir_coms := v_incluir_coms and v_asunto_id is null and v_trd is null;
  select case when u.perfil = 'dependencia' then coalesce(u.dependencia_id, -1) end into v_scope
    from usuario u where u.id = p_usuario_id;

  return (
    with resultados as (
      select 'documento'::text as origen, doc.id, doc.consecutivo, doc.anio::int as anio, doc.fecha_documento as fecha,
             doc.tipo_comunicacion::text as tipo, coalesce(doc.titulo, ar.nombre_original, '(sin título)') as titulo,
             case when doc.tipo_comunicacion = 'ENT' then coalesce(doc.remitente, doc.destinatario)
                  else coalesce(doc.destinatario, doc.remitente) end as contraparte,
             d.nombre as dependencia, doc.dependencia_id, a.nombre as asunto, t.codigo as trd,
             doc.archivo_id::text as archivo_id, doc.caja, doc.carpeta, null::text as estado, null::text as consecutivo_original
        from documento doc
        join dependencia d on d.id = doc.dependencia_id
        left join asunto a on a.id = doc.asunto_id
        left join trd t on t.id = a.trd_id
        left join archivo ar on ar.id = doc.archivo_id
       where v_incluir_docs and doc.estado = 'clasificado'
         and (v_scope is null or doc.dependencia_id = v_scope)
         and (v_anio is null or doc.anio = v_anio)
         and (v_mes is null or extract(month from doc.fecha_documento) = v_mes)
         and (v_dia is null or extract(day from doc.fecha_documento) = v_dia)
         and (v_dep is null or doc.dependencia_id = v_dep)
         and (v_tipo is null or doc.tipo_comunicacion = v_tipo)
         and (v_asunto_id is null or doc.asunto_id = v_asunto_id)
         and (v_asunto is null or a.nombre ilike fn_patron_contiene(v_asunto))
         and (v_consecutivo is null or ltrim(split_part(doc.consecutivo, '/', 1), '0') = v_consecutivo)
         and (v_persona is null or doc.remitente ilike fn_patron_contiene(v_persona)
              or doc.destinatario ilike fn_patron_contiene(v_persona))
         and (v_trd is null or t.codigo like replace(replace(v_trd, '%', ''), '_', '\_') || '%')
         and (v_texto is null or doc.titulo ilike fn_patron_contiene(v_texto)
              or doc.observaciones ilike fn_patron_contiene(v_texto) or doc.consecutivo ilike fn_patron_contiene(v_texto))
      union all
      select 'comunicacion', c.id, c.consecutivo, c.anio::int, (c.fecha_recepcion at time zone 'America/Bogota')::date,
             c.tipo::text, c.asunto,
             case when c.tipo = 'ENT' then c.remitente_nombre else c.destinatario_nombre end,
             d.nombre, c.dependencia_id, null, null, null, null, null, c.estado::text, c.consecutivo_original
        from comunicacion c
        left join dependencia d on d.id = c.dependencia_id
       where v_incluir_coms and c.estado <> 'anulada'
         and (v_scope is null or c.dependencia_id = v_scope)
         and (v_anio is null or c.anio = v_anio)
         and (v_mes is null or extract(month from c.fecha_recepcion at time zone 'America/Bogota') = v_mes)
         and (v_dia is null or extract(day from c.fecha_recepcion at time zone 'America/Bogota') = v_dia)
         and (v_dep is null or c.dependencia_id = v_dep)
         and (v_tipo is null or c.tipo = v_tipo)
         and (v_asunto is null or c.asunto ilike fn_patron_contiene(v_asunto))
         and (v_consecutivo is null or ltrim(coalesce(c.consecutivo_original, ''), '0') = v_consecutivo
              or (v_consecutivo ~ '^\d{1,9}$' and c.numero = v_consecutivo::int and c.origen <> 'historico'))
         and (v_persona is null or c.remitente_nombre ilike fn_patron_contiene(v_persona)
              or c.destinatario_nombre ilike fn_patron_contiene(v_persona)
              or c.remitente_correo ilike fn_patron_contiene(v_persona))
         and (v_texto is null or c.asunto ilike fn_patron_contiene(v_texto) or c.consecutivo ilike fn_patron_contiene(v_texto))
    )
    select jsonb_build_object(
      'total', (select count(*) from resultados),
      'pagina', greatest(coalesce(p_pagina, 1), 1),
      'limite', v_limite,
      'incluye', jsonb_build_object('documentos', v_incluir_docs, 'comunicaciones', v_incluir_coms),
      'filas', coalesce((select jsonb_agg(to_jsonb(r) order by r.fecha desc nulls last, r.origen, r.id desc)
                           from (select * from resultados order by fecha desc nulls last, origen, id desc
                                 limit v_limite offset v_offset) r), '[]'::jsonb))
  );
end $$;

-- Solo el backend (service_role) llama estas funciones.
do $$
declare f text;
begin
  foreach f in array array[
    'fn_alcance_consulta(bigint, text, text, text)', 'fn_patron_contiene(text)',
    'fn_archivo_arbol(bigint)', 'fn_archivo_buscar(bigint, jsonb, integer, integer)']
  loop
    execute format('revoke execute on function %s from public', f);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke execute on function %s from anon', f);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke execute on function %s from authenticated', f);
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
      execute format('grant execute on function %s to service_role', f);
    end if;
  end loop;
end $$;
