-- =============================================================================
--  28 Historias académicas (árbol, lista y ficha), transferencias en Consulta › Buscar y en el Archivo
--
--  - fn_historias_arbol: Estado → Año → Nivel → Programa con cuántas historias hay (RF-AC-020).
--  - fn_historias_listar: historias de un nodo o de una búsqueda (nombre, cédula o título de un
--    documento), 20 por página, con el número de documentos.
--  - fn_historia_documentos: documentos de una historia (título, fecha, archivo).
--    Las tres exigen historias.consultar y respetan fn_puede_ver_historia (RN-AC-06: Registro
--    Académico solo activas; Archivo Central y Secretaría General, todas). Sin IA (RN-AC-13).
--  - fn_archivo_buscar: también busca transferencias (código, dependencia, año, quién la entregó,
--    contenido), con cargas.transferencia, transferencias.recibir o documentos.consultar; un usuario
--    de Dependencia solo ve las suyas.
--  - fn_archivo_arbol: cada año de una dependencia cuenta también sus transferencias, y aparecen los
--    años que solo tienen transferencias.
-- =============================================================================

create or replace function fn_historias_arbol(p_usuario_id bigint)
returns jsonb
language plpgsql
as $$
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'historias.consultar', 'consultar', 'historia_academica', null) then
    return jsonb_build_object('denegado', true, 'funcion', 'historias.consultar');
  end if;
  return coalesce((
    with base as (
      select h.estado::text as estado, h.anio::int as anio, n.id as nivel_id, n.nombre as nivel, n.tipo as nivel_tipo,
             coalesce(n.orden, 100) as nivel_orden, p.id as programa_id, p.nombre as programa
        from historia_academica h
        join programa_academico p on p.id = h.programa_id
        left join nivel_formacion n on n.id = p.nivel_id
       where fn_puede_ver_historia(p_usuario_id, h.id)
    )
    select jsonb_agg(jsonb_build_object('estado', e.estado, 'total', e.total, 'anios', e.anios)
                     order by case e.estado when 'graduado' then 1 when 'retirado' then 2 else 3 end)
      from (
        select b.estado, count(*)::int as total,
               (select jsonb_agg(jsonb_build_object('anio', a.anio, 'total', a.total, 'niveles', a.niveles) order by a.anio desc nulls last)
                  from (select b2.anio, count(*)::int as total,
                               (select jsonb_agg(jsonb_build_object('nivel_id', nv.nivel_id, 'nivel', nv.nivel, 'tipo', nv.nivel_tipo,
                                                                    'total', nv.total, 'programas', nv.programas) order by nv.nivel_orden, nv.nivel)
                                  from (select b3.nivel_id, coalesce(b3.nivel, 'Sin nivel') as nivel, b3.nivel_tipo, min(b3.nivel_orden) as nivel_orden,
                                               count(*)::int as total,
                                               (select jsonb_agg(jsonb_build_object('programa_id', pr.programa_id, 'programa', pr.programa, 'total', pr.total) order by pr.programa)
                                                  from (select b4.programa_id, b4.programa, count(*)::int as total
                                                          from base b4
                                                         where b4.estado = b.estado and b4.anio is not distinct from b2.anio
                                                           and b4.nivel_id is not distinct from b3.nivel_id
                                                         group by 1, 2) pr) as programas
                                          from base b3
                                         where b3.estado = b.estado and b3.anio is not distinct from b2.anio
                                         group by b3.nivel_id, b3.nivel, b3.nivel_tipo) nv) as niveles
                          from base b2 where b2.estado = b.estado group by b2.anio) a) as anios
          from base b group by b.estado
      ) e
  ), '[]'::jsonb);
end $$;

create or replace function fn_historias_listar(
  p_usuario_id bigint, p_filtros jsonb default '{}'::jsonb, p_pagina integer default 1, p_limite integer default 20)
returns jsonb
language plpgsql
as $$
declare
  f jsonb := coalesce(p_filtros, '{}'::jsonb);
  v_estado text := nullif(trim(f ->> 'estado'), '');
  v_anio int := nullif(f ->> 'anio', '')::int;
  v_nivel bigint := nullif(f ->> 'nivel_id', '')::bigint;
  v_programa bigint := nullif(f ->> 'programa_id', '')::bigint;
  v_q text := nullif(trim(f ->> 'q'), '');
  v_limite int := least(greatest(coalesce(p_limite, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_pagina, 1), 1) - 1) * least(greatest(coalesce(p_limite, 20), 1), 100);
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'historias.consultar', 'consultar', 'historia_academica', null) then
    return jsonb_build_object('denegado', true, 'funcion', 'historias.consultar');
  end if;
  return (
    with filas as (
      select h.id, h.estado::text as estado, h.anio::int as anio, e.apellidos, e.nombres, e.tipo_documento,
             e.numero_documento, p.id as programa_id, p.nombre as programa, n.id as nivel_id, n.nombre as nivel,
             (select count(*)::int from historia_documento hd where hd.historia_id = h.id and not hd.anulado) as documentos,
             (select max(hd.cargado_en) from historia_documento hd where hd.historia_id = h.id and not hd.anulado) as ultimo_cargue
        from historia_academica h
        join estudiante e on e.id = h.estudiante_id
        join programa_academico p on p.id = h.programa_id
        left join nivel_formacion n on n.id = p.nivel_id
       where fn_puede_ver_historia(p_usuario_id, h.id)
         and (v_estado is null or h.estado::text = v_estado)
         and (v_anio is null or h.anio = v_anio)
         and (v_nivel is null or p.nivel_id = v_nivel)
         and (v_programa is null or h.programa_id = v_programa)
         and (v_q is null
              or (e.apellidos || ' ' || e.nombres) ilike fn_patron_contiene(v_q)
              or (e.nombres || ' ' || e.apellidos) ilike fn_patron_contiene(v_q)
              or e.numero_documento = regexp_replace(v_q, '[^0-9A-Za-z]', '', 'g')
              or exists (select 1 from historia_documento hd where hd.historia_id = h.id and not hd.anulado
                                                                and hd.descripcion ilike fn_patron_contiene(v_q)))
    )
    select jsonb_build_object(
      'total', (select count(*) from filas),
      'pagina', greatest(coalesce(p_pagina, 1), 1),
      'limite', v_limite,
      'filas', coalesce((select jsonb_agg(to_jsonb(r) order by r.apellidos, r.nombres, r.id)
                           from (select * from filas order by apellidos, nombres, id limit v_limite offset v_offset) r), '[]'::jsonb))
  );
end $$;

create or replace function fn_historia_documentos(p_usuario_id bigint, p_historia_id bigint)
returns jsonb
language plpgsql
as $$
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'historias.consultar', 'consultar', 'historia_academica', p_historia_id::text)
     or not fn_puede_ver_historia(p_usuario_id, p_historia_id) then
    return jsonb_build_object('denegado', true, 'funcion', 'historias.consultar');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', hd.id, 'titulo', coalesce(hd.descripcion, 'Documento'), 'fecha', hd.fecha_documento,
             'cargado_en', hd.cargado_en, 'archivo_id', hd.archivo_id, 'archivo_nombre', a.nombre_original,
             'paginas', a.paginas) order by hd.cargado_en desc)
      from historia_documento hd
      join archivo a on a.id = hd.archivo_id
     where hd.historia_id = p_historia_id and not hd.anulado
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
  v_incluir_hist boolean;
  v_incluir_trf boolean;
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
  if v_alcance not in ('todo', 'documentos', 'comunicaciones', 'historias', 'transferencias') then
    raise exception '[campo:alcance|tipo:lista] Alcance no válido: todo, documentos, comunicaciones, historias o transferencias' using errcode = '22023';
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
  v_incluir_hist := v_alcance in ('todo', 'historias') and fn_tiene_permiso(p_usuario_id, 'historias.consultar');
  v_incluir_trf := v_alcance in ('todo', 'transferencias') and (fn_tiene_permiso(p_usuario_id, 'cargas.transferencia')
                   or fn_tiene_permiso(p_usuario_id, 'transferencias.recibir') or fn_tiene_permiso(p_usuario_id, 'documentos.consultar'));
  if not v_incluir_docs and not v_incluir_coms and not v_incluir_hist and not v_incluir_trf then
    perform fn_catalogo_autorizar(p_usuario_id,
      case v_alcance when 'comunicaciones' then 'comunicaciones.consultar'
                     when 'historias' then 'historias.consultar'
                     when 'transferencias' then 'cargas.transferencia' else 'documentos.consultar' end,
      'consultar', 'busqueda', null);
    return jsonb_build_object('denegado', true,
      'funcion', case v_alcance when 'comunicaciones' then 'comunicaciones.consultar'
                                when 'historias' then 'historias.consultar'
                                when 'transferencias' then 'cargas.transferencia' else 'documentos.consultar' end);
  end if;
  -- Las comunicaciones no tienen asunto ni TRD: con esos filtros solo se buscan documentos.
  v_incluir_coms := v_incluir_coms and v_asunto_id is null and v_trd is null;
  -- Las historias se buscan por título, nombre o cédula (texto o persona) y año; no tienen dependencia,
  -- tipo, asunto, TRD ni consecutivo. Sin algo escrito no se listan (Ley 1581: solo lo buscado).
  v_incluir_hist := v_incluir_hist and coalesce(v_persona, v_texto) is not null
                    and v_dep is null and v_tipo is null and v_asunto_id is null and v_asunto is null
                    and v_trd is null and v_consecutivo is null and v_mes is null and v_dia is null;
  -- Las transferencias no tienen tipo de comunicación, asunto, TRD ni fecha por mes y día.
  v_incluir_trf := v_incluir_trf and v_tipo is null and v_asunto_id is null and v_asunto is null
                   and v_trd is null and v_mes is null and v_dia is null;
  select case when u.perfil = 'dependencia' then coalesce(u.dependencia_id, -1) end into v_scope
    from usuario u where u.id = p_usuario_id;

  return (
    with resultados as (
      select 'documento'::text as origen, doc.id, doc.consecutivo, doc.anio::int as anio, doc.fecha_documento as fecha,
             doc.tipo_comunicacion::text as tipo, coalesce(doc.titulo, ar.nombre_original, '(sin título)') as titulo,
             case when doc.tipo_comunicacion = 'ENT' then coalesce(doc.remitente, doc.destinatario)
                  else coalesce(doc.destinatario, doc.remitente) end as contraparte,
             d.nombre as dependencia, doc.dependencia_id, a.nombre as asunto, t.codigo as trd,
             doc.archivo_id::text as archivo_id, doc.carro, doc.estante, doc.bandeja, doc.caja, doc.carpeta,
             null::text as estado, null::text as consecutivo_original
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
             d.nombre, c.dependencia_id, null, null, null, null, null, null, null, null, c.estado::text, c.consecutivo_original
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
      union all
      -- Historias académicas: un resultado por documento de la historia.
      select 'historia', hd.id, null, h.anio::int, coalesce(hd.fecha_documento, (hd.cargado_en at time zone 'America/Bogota')::date),
             null, coalesce(hd.descripcion, 'Historia académica'),
             e.apellidos || ' ' || e.nombres, p.nombre, null, null, null,
             hd.archivo_id::text, null, null, null, null, null, h.estado::text, null
        from historia_documento hd
        join historia_academica h on h.id = hd.historia_id
        join estudiante e on e.id = h.estudiante_id
        join programa_academico p on p.id = h.programa_id
       where v_incluir_hist and not hd.anulado
         and fn_puede_ver_historia(p_usuario_id, h.id)
         and (v_anio is null or h.anio = v_anio)
         and (
           (v_persona is not null and ((e.apellidos || ' ' || e.nombres) ilike fn_patron_contiene(v_persona)
              or (e.nombres || ' ' || e.apellidos) ilike fn_patron_contiene(v_persona)
              or e.numero_documento = regexp_replace(v_persona, '[^0-9A-Za-z]', '', 'g')))
           or (v_texto is not null and ((e.apellidos || ' ' || e.nombres) ilike fn_patron_contiene(v_texto)
              or (e.nombres || ' ' || e.apellidos) ilike fn_patron_contiene(v_texto)
              or e.numero_documento = regexp_replace(v_texto, '[^0-9A-Za-z]', '', 'g')
              or hd.descripcion ilike fn_patron_contiene(v_texto)))
         )
      union all
      -- Transferencias: código, dependencia, año, quién la entregó, contenido y descripción.
      select 'transferencia', t.id, t.codigo, t.anio::int, (t.registrado_en at time zone 'America/Bogota')::date,
             null, 'Transferencia ' || case t.tipo::text when 'fisica' then 'física' when 'digital' then 'digital' else t.tipo::text end
                   || coalesce(' · ' || nullif(t.contenido, ''), ''),
             t.funcionario_entrega, d.nombre, t.dependencia_id, null, null,
             t.acta_archivo_id::text, t.carro, t.estante, t.bandeja, null, null, t.estado::text, null
        from transferencia t
        join dependencia d on d.id = t.dependencia_id
       where v_incluir_trf and t.anulado_en is null
         and (v_scope is null or t.dependencia_id = v_scope)
         and (v_anio is null or t.anio = v_anio)
         and (v_dep is null or t.dependencia_id = v_dep)
         and (v_consecutivo is null or t.codigo ilike fn_patron_contiene(v_consecutivo))
         and (v_persona is null or t.funcionario_entrega ilike fn_patron_contiene(v_persona))
         and (v_texto is null or t.codigo ilike fn_patron_contiene(v_texto) or t.contenido ilike fn_patron_contiene(v_texto)
              or t.descripcion ilike fn_patron_contiene(v_texto) or t.funcionario_entrega ilike fn_patron_contiene(v_texto)
              or d.nombre ilike fn_patron_contiene(v_texto))
    )
    select jsonb_build_object(
      'total', (select count(*) from resultados),
      'pagina', greatest(coalesce(p_pagina, 1), 1),
      'limite', v_limite,
      'incluye', jsonb_build_object('documentos', v_incluir_docs, 'comunicaciones', v_incluir_coms, 'historias', v_incluir_hist,
                                     'transferencias', v_incluir_trf),
      'filas', coalesce((select jsonb_agg(to_jsonb(r) order by r.fecha desc nulls last, r.origen, r.id desc)
                           from (select * from resultados order by fecha desc nulls last, origen, id desc
                                 limit v_limite offset v_offset) r), '[]'::jsonb))
  );
end $$;

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
    ),
    trf as (
      select t.dependencia_id, t.anio::int as anio, count(*)::int as n
        from transferencia t
       where t.anulado_en is null
         and (v_alcance.dependencia_id is null or t.dependencia_id = v_alcance.dependencia_id)
       group by 1, 2
    ),
    anios as (
      select dependencia_id, anio from conteos union select dependencia_id, anio from trf
    )
    select jsonb_agg(jsonb_build_object(
             'dependencia_id', d.id, 'codigo', d.codigo, 'nombre', d.nombre,
             'total', coalesce((select sum(c.n) from conteos c where c.dependencia_id = d.id), 0),
             'transferencias', coalesce((select sum(t.n) from trf t where t.dependencia_id = d.id), 0),
             'anios', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'anio', y.anio,
                        'total', coalesce((select sum(c.n) from conteos c where c.dependencia_id = d.id and c.anio = y.anio), 0),
                        'transferencias', coalesce((select t.n from trf t where t.dependencia_id = d.id and t.anio = y.anio), 0),
                        'asuntos', coalesce((
                          select jsonb_agg(jsonb_build_object('asunto_id', a.id, 'nombre', a.nombre, 'trd', tr.codigo, 'total', c.n)
                                           order by a.nombre)
                            from conteos c
                            join asunto a on a.id = c.asunto_id
                            left join trd tr on tr.id = a.trd_id
                           where c.dependencia_id = d.id and c.anio = y.anio), '[]'::jsonb))
                      order by y.anio desc)
                 from anios y where y.dependencia_id = d.id), '[]'::jsonb))
           order by d.nombre)
      from dependencia d
     where (v_alcance.dependencia_id is null or d.id = v_alcance.dependencia_id)
       and (d.estado = 'activo' or exists (select 1 from anios y where y.dependencia_id = d.id))
  ), '[]'::jsonb);
end $$;

-- Solo el backend (service_role) llama estas funciones.
do $$
declare f text;
begin
  foreach f in array array['fn_historias_arbol(bigint)', 'fn_historias_listar(bigint, jsonb, integer, integer)',
                           'fn_historia_documentos(bigint, bigint)', 'fn_archivo_buscar(bigint, jsonb, integer, integer)',
                           'fn_archivo_arbol(bigint)']
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
