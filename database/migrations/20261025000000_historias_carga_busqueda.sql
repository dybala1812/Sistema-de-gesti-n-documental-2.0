-- =============================================================================
--  25 Historias académicas: cargar cada documento con un título y buscarlas (RF-AC-020, 021, 014)
--
--  - fn_historia_cargar: guarda UN documento de la historia de un estudiante, con un TÍTULO que
--    escribe quien carga (p. ej. "Acta de grado") y que sirve para buscarlo. El nombre y la cédula
--    salen del nombre del archivo (APELLIDOS NOMBRES - cédula.pdf); si el estudiante ya existe
--    (misma cédula) se usa el suyo, y si ya tiene historia en ese programa el documento se agrega
--    a ella (RF-AC-021). Mismo archivo en la misma historia = duplicado (RN-AC-11). Sin IA (RN-AC-13).
--    La auditoría la registran los triggers de estudiante, historia_academica e historia_documento.
--  - fn_archivo_buscar: Consulta › Buscar también encuentra historias por título, nombre o cédula
--    (alcance 'historias'), con historias.consultar y fn_puede_ver_historia (RN-AC-06: Registro
--    Académico ve las activas; Archivo Central y Secretaría General, todas). De paso devuelve
--    carro, estante y bandeja de los documentos (D-23).
-- =============================================================================

create index if not exists historia_documento_descripcion_trgm on historia_documento using gin (descripcion gin_trgm_ops);
create index if not exists estudiante_nombres_apellidos_trgm
  on estudiante using gin ((nombres || ' ' || apellidos) gin_trgm_ops);

create or replace function fn_historia_cargar(p_usuario_id bigint, p_datos jsonb)
returns jsonb
language plpgsql
as $$
declare
  d            jsonb := coalesce(p_datos, '{}'::jsonb);
  v_archivo    uuid;
  v_hash       char(64);
  v_programa   bigint := nullif(d ->> 'programa_id', '')::bigint;
  v_estado     estado_historia;
  v_anio       smallint := nullif(d ->> 'anio', '')::smallint;
  v_tipo_doc   text := upper(coalesce(nullif(trim(d ->> 'tipo_documento'), ''), 'CC'));
  v_numero     text := nullif(regexp_replace(coalesce(d ->> 'numero_documento', ''), '[^0-9A-Za-z]', '', 'g'), '');
  v_apellidos  text := nullif(upper(trim(regexp_replace(coalesce(d ->> 'apellidos', ''), '\s+', ' ', 'g'))), '');
  v_nombres    text := nullif(upper(trim(regexp_replace(coalesce(d ->> 'nombres', ''), '\s+', ' ', 'g'))), '');
  v_est        estudiante;
  v_hist       historia_academica;
  v_doc_id     bigint;
  v_nueva      boolean := false;
  v_est_existia boolean := true;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'cargas.historias', 'crear', 'historia_documento', null) then
    return jsonb_build_object('denegado', true, 'funcion', 'cargas.historias');
  end if;

  begin
    v_archivo := nullif(d ->> 'archivo_id', '')::uuid;
  exception when invalid_text_representation then
    raise exception '[campo:archivo_id|tipo:formato] El archivo no es válido' using errcode = '22023';
  end;
  select hash_sha256 into v_hash from archivo where id = v_archivo;
  if v_archivo is null or v_hash is null then
    raise exception '[campo:archivo_id|tipo:existente] Falta el archivo' using errcode = '22023';
  end if;
  if v_apellidos is null then
    raise exception '[campo:apellidos|tipo:obligatorio] Escriba los apellidos del estudiante' using errcode = '22023';
  end if;
  if v_nombres is null then
    raise exception '[campo:nombres|tipo:obligatorio] Escriba los nombres del estudiante' using errcode = '22023';
  end if;
  if v_numero is null or length(v_numero) not between 5 and 12 then
    raise exception '[campo:numero_documento|tipo:formato] El documento de identidad debe tener entre 5 y 12 caracteres' using errcode = '22023';
  end if;
  if v_programa is null or not exists (select 1 from programa_academico where id = v_programa and estado = 'activo') then
    raise exception '[campo:programa_id|tipo:existente] El programa no existe o está inactivo' using errcode = '22023';
  end if;
  begin
    v_estado := coalesce(nullif(d ->> 'estado', ''), 'graduado')::estado_historia;
  exception when invalid_text_representation then
    raise exception '[campo:estado|tipo:lista] Estado no válido: activa, retirado o graduado' using errcode = '22023';
  end;
  if v_estado <> 'activa' and v_anio is null then
    raise exception '[campo:anio|tipo:obligatorio] Falta el año de grado o de retiro' using errcode = '22023';
  end if;

  -- Estudiante: por documento de identidad. Si ya existe, se usa el suyo (no se cambian sus datos aquí).
  select * into v_est from estudiante where tipo_documento = v_tipo_doc and numero_documento = v_numero;
  if not found then
    insert into estudiante (tipo_documento, numero_documento, apellidos, nombres)
    values (v_tipo_doc, v_numero, v_apellidos, v_nombres)
    returning * into v_est;
    v_est_existia := false;
  end if;

  -- Historia: una por estudiante y programa; si ya existe, el documento se agrega a ella.
  select * into v_hist from historia_academica where estudiante_id = v_est.id and programa_id = v_programa for update;
  if not found then
    insert into historia_academica (estudiante_id, programa_id, estado, anio)
    values (v_est.id, v_programa, v_estado, v_anio)
    returning * into v_hist;
    v_nueva := true;
  end if;

  begin
    insert into historia_documento (historia_id, archivo_id, hash_sha256, descripcion, cargado_por)
    values (v_hist.id, v_archivo, v_hash, nullif(trim(coalesce(d ->> 'titulo', d ->> 'descripcion')), ''), p_usuario_id)
    returning id into v_doc_id;
  exception when unique_violation then
    raise exception '[campo:archivo|tipo:duplicado] Ese archivo ya está en la historia de % %', v_est.apellidos, v_est.nombres
      using errcode = '22023';
  end;

  return jsonb_build_object(
    'documento_id', v_doc_id, 'historia_id', v_hist.id, 'estudiante_id', v_est.id,
    'nueva_historia', v_nueva, 'estado', v_hist.estado, 'anio', v_hist.anio,
    'estudiante', jsonb_build_object('apellidos', v_est.apellidos, 'nombres', v_est.nombres,
                                     'existia', v_est_existia,
                                     -- Ya existía con otro nombre: se usó el guardado (corregirlo es otra acción).
                                     'nombre_distinto', v_est_existia and (v_est.apellidos <> v_apellidos or v_est.nombres <> v_nombres)));
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
  if v_alcance not in ('todo', 'documentos', 'comunicaciones', 'historias') then
    raise exception '[campo:alcance|tipo:lista] Alcance no válido: todo, documentos, comunicaciones o historias' using errcode = '22023';
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
  if not v_incluir_docs and not v_incluir_coms and not v_incluir_hist then
    perform fn_catalogo_autorizar(p_usuario_id,
      case v_alcance when 'comunicaciones' then 'comunicaciones.consultar'
                     when 'historias' then 'historias.consultar' else 'documentos.consultar' end,
      'consultar', 'busqueda', null);
    return jsonb_build_object('denegado', true,
      'funcion', case v_alcance when 'comunicaciones' then 'comunicaciones.consultar'
                                when 'historias' then 'historias.consultar' else 'documentos.consultar' end);
  end if;
  -- Las comunicaciones no tienen asunto ni TRD: con esos filtros solo se buscan documentos.
  v_incluir_coms := v_incluir_coms and v_asunto_id is null and v_trd is null;
  -- Las historias se buscan por título, nombre o cédula (texto o persona) y año; no tienen dependencia,
  -- tipo, asunto, TRD ni consecutivo. Sin algo escrito no se listan (Ley 1581: solo lo buscado).
  v_incluir_hist := v_incluir_hist and coalesce(v_persona, v_texto) is not null
                    and v_dep is null and v_tipo is null and v_asunto_id is null and v_asunto is null
                    and v_trd is null and v_consecutivo is null and v_mes is null and v_dia is null;
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
    )
    select jsonb_build_object(
      'total', (select count(*) from resultados),
      'pagina', greatest(coalesce(p_pagina, 1), 1),
      'limite', v_limite,
      'incluye', jsonb_build_object('documentos', v_incluir_docs, 'comunicaciones', v_incluir_coms, 'historias', v_incluir_hist),
      'filas', coalesce((select jsonb_agg(to_jsonb(r) order by r.fecha desc nulls last, r.origen, r.id desc)
                           from (select * from resultados order by fecha desc nulls last, origen, id desc
                                 limit v_limite offset v_offset) r), '[]'::jsonb))
  );
end $$;

-- Solo el backend (service_role) llama estas funciones.
do $$
declare f text;
begin
  foreach f in array array['fn_historia_cargar(bigint, jsonb)', 'fn_archivo_buscar(bigint, jsonb, integer, integer)']
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
