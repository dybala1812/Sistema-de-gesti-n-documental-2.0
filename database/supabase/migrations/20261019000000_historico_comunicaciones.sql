-- SGD-044 / RF-AC-019 / RN-AC-10: registro histórico de comunicaciones.
--
--   - fn_historico_importar: importa las filas de un Excel histórico ya mapeadas a columnas del sistema.
--     Vista previa (p_confirmar = false) o confirmación. Cada fila queda como comunicación CERRADA con
--     origen 'historico', consecutivo del sistema en el bloque 900001+ de su tipo y año (no choca con el
--     contador de las comunicaciones nuevas) y el número original en consecutivo_original.
--     Idempotente: una fila ya importada (mismo tipo, año y número original) no se vuelve a crear.
--     Un número repetido dentro del mismo archivo (mismo tipo y año) se marca para revisión y no se importa.
--   - fn_historico_calendario: totales por mes de un año (todas, cerradas en el sistema, importadas).
--   - fn_historico_mes: comunicaciones de un mes, paginadas.
-- Importar requiere cargas.historico; consultar, comunicaciones.consultar (un usuario de Dependencia solo
-- ve las de su dependencia). Los intentos denegados quedan en la auditoría.

-- Tipo de comunicación a partir del texto del Excel.
create or replace function fn_historico_tipo(p_valor text)
returns tipo_comunicacion
language sql stable
as $$
  select case
    when v in ('ent', 'entrada', 'entradas', 'recibida', 'recibidas', 'recibido', 'recibidos') then 'ENT'::tipo_comunicacion
    when v in ('sal', 'salida', 'salidas', 'enviada', 'enviadas', 'enviado', 'enviados') then 'SAL'::tipo_comunicacion
    when v in ('int', 'interna', 'internas', 'interno', 'internos') then 'INT'::tipo_comunicacion
  end
  from (select trim(fn_normalizar(p_valor)) as v) s
$$;

-- Valida y normaliza una fila. Devuelve {ok: true, ...datos} o {ok: false, campo, error}.
create or replace function fn_historico_parsear(p_fila jsonb, p_tipo_defecto text default null)
returns jsonb
language plpgsql
as $$
declare
  v_tipo_texto text := coalesce(nullif(trim(p_fila ->> 'tipo'), ''), nullif(trim(p_tipo_defecto), ''));
  v_tipo tipo_comunicacion := fn_historico_tipo(v_tipo_texto);
  v_numero text := nullif(trim(p_fila ->> 'numero_original'), '');
  v_asunto text := nullif(trim(p_fila ->> 'asunto'), '');
  v_dep_texto text := nullif(trim(p_fila ->> 'dependencia'), '');
  v_fecha date;
  v_dep_id bigint;
  v_aviso text;
begin
  if v_tipo is null then
    return jsonb_build_object('ok', false, 'campo', 'tipo', 'error',
      case when v_tipo_texto is null then 'Falta el tipo (recibida, enviada o interna)'
           else format('Tipo «%s» no reconocido: use recibida, enviada o interna', v_tipo_texto) end);
  end if;
  if v_numero is null then
    return jsonb_build_object('ok', false, 'campo', 'numero_original', 'error', 'Falta el número original');
  end if;
  if length(v_numero) > 50 then
    return jsonb_build_object('ok', false, 'campo', 'numero_original', 'error', 'El número original es demasiado largo (máximo 50 caracteres)');
  end if;
  if nullif(trim(p_fila ->> 'fecha'), '') is null then
    return jsonb_build_object('ok', false, 'campo', 'fecha', 'error', 'Falta la fecha');
  end if;
  begin
    v_fecha := (trim(p_fila ->> 'fecha'))::date;
  exception when others then
    return jsonb_build_object('ok', false, 'campo', 'fecha', 'error', format('Fecha «%s» no válida (use AAAA-MM-DD)', p_fila ->> 'fecha'));
  end;
  if v_fecha < date '1990-01-01' or v_fecha > current_date then
    return jsonb_build_object('ok', false, 'campo', 'fecha', 'error', 'La fecha debe estar entre 1990 y hoy');
  end if;
  if v_asunto is null then
    return jsonb_build_object('ok', false, 'campo', 'asunto', 'error', 'Falta el asunto');
  end if;
  if v_dep_texto is not null then
    select id into v_dep_id from dependencia
     where codigo = v_dep_texto or fn_normalizar(nombre) = fn_normalizar(v_dep_texto)
     order by (codigo = v_dep_texto) desc
     limit 1;
    if v_dep_id is null then
      v_aviso := format('No se encontró la dependencia «%s»: se importa sin dependencia', v_dep_texto);
    end if;
  end if;
  return jsonb_build_object(
    'ok', true, 'tipo', v_tipo, 'anio', extract(year from v_fecha)::int, 'numero_original', v_numero,
    'fecha', v_fecha, 'asunto', left(v_asunto, 500),
    'remitente', left(nullif(trim(p_fila ->> 'remitente'), ''), 300),
    'destinatario', left(nullif(trim(p_fila ->> 'destinatario'), ''), 300),
    'dependencia_id', v_dep_id,
    'observaciones', nullif(trim(p_fila ->> 'observaciones'), ''),
    'aviso', v_aviso);
end $$;

create or replace function fn_historico_importar(
  p_usuario_id bigint, p_filas jsonb, p_confirmar boolean default false, p_tipo_defecto text default null)
returns jsonb
language plpgsql
as $$
declare
  v_fila jsonb;
  v_p jsonb;
  v_n integer := 0;
  v_claves jsonb := '{}'::jsonb;   -- "tipo|año|NÚMERO" → filas donde aparece
  v_clave text;
  v_tipo tipo_comunicacion;
  v_anio integer;
  v_existente text;
  v_numero integer;
  v_id bigint;
  v_consecutivo text;
  v_resultados jsonb := '[]'::jsonb;
  v_nuevas integer := 0; v_ya integer := 0; v_revisar integer := 0; v_errores integer := 0;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if jsonb_typeof(p_filas) is distinct from 'array' or jsonb_array_length(p_filas) = 0 then
    raise exception '[campo:filas|tipo:obligatorio] El archivo no tiene filas para importar' using errcode = '22023';
  end if;
  if jsonb_array_length(p_filas) > 5000 then
    raise exception '[campo:filas|tipo:rango] Máximo 5.000 filas por importación' using errcode = '22023';
  end if;
  if nullif(trim(p_tipo_defecto), '') is not null and fn_historico_tipo(p_tipo_defecto) is null then
    raise exception '[campo:tipo|tipo:lista] Tipo «%» no reconocido: use recibida, enviada o interna', p_tipo_defecto using errcode = '22023';
  end if;
  if not fn_catalogo_autorizar(p_usuario_id, 'cargas.historico', 'importar', 'comunicacion_historico', null) then
    return jsonb_build_object('denegado', true, 'funcion', 'cargas.historico');
  end if;

  -- 1.ª pasada: números repetidos dentro del mismo archivo.
  for v_fila in select value from jsonb_array_elements(p_filas) loop
    v_n := v_n + 1;
    v_p := fn_historico_parsear(v_fila, p_tipo_defecto);
    if (v_p ->> 'ok')::boolean then
      v_clave := concat_ws('|', v_p ->> 'tipo', v_p ->> 'anio', upper(v_p ->> 'numero_original'));
      v_claves := v_claves || jsonb_build_object(v_clave, coalesce(v_claves -> v_clave, '[]'::jsonb) || to_jsonb(v_n));
    end if;
  end loop;

  -- Dos importaciones a la vez no deben tomar el mismo número del bloque histórico.
  perform pg_advisory_xact_lock(hashtext('sgd_historico_importar'));

  begin
    v_n := 0;
    for v_fila in select value from jsonb_array_elements(p_filas) loop
      v_n := v_n + 1;
      v_p := fn_historico_parsear(v_fila, p_tipo_defecto);
      if not (v_p ->> 'ok')::boolean then
        v_errores := v_errores + 1;
        v_resultados := v_resultados || jsonb_build_object('fila', v_n, 'resultado', 'error', 'campo', v_p ->> 'campo', 'error', v_p ->> 'error');
        continue;
      end if;

      v_tipo := (v_p ->> 'tipo')::tipo_comunicacion;
      v_anio := (v_p ->> 'anio')::integer;
      v_clave := concat_ws('|', v_p ->> 'tipo', v_p ->> 'anio', upper(v_p ->> 'numero_original'));
      if jsonb_array_length(v_claves -> v_clave) > 1 then
        v_revisar := v_revisar + 1;
        v_resultados := v_resultados || jsonb_build_object('fila', v_n, 'resultado', 'revisar', 'campo', 'numero_original',
          'error', format('El número %s de %s se repite en las filas %s del archivo: corríjalo y vuelva a importar',
                          v_p ->> 'numero_original', v_anio,
                          (select string_agg(value::text, ', ') from jsonb_array_elements(v_claves -> v_clave))));
        continue;
      end if;

      select consecutivo into v_existente from comunicacion
       where tipo = v_tipo and anio = v_anio and upper(consecutivo_original) = upper(v_p ->> 'numero_original')
       limit 1;
      if v_existente is not null then
        v_ya := v_ya + 1;
        v_resultados := v_resultados || jsonb_build_object('fila', v_n, 'resultado', 'ya_importada', 'consecutivo', v_existente);
        continue;
      end if;

      begin
        select coalesce(max(numero), 900000) + 1 into v_numero
          from comunicacion where tipo = v_tipo and anio = v_anio and numero > 900000;
        insert into comunicacion (tipo, origen, anio, numero, consecutivo_original, asunto, remitente_nombre,
                                  destinatario_nombre, dependencia_id, cuerpo, fecha_recepcion, registrado_por)
        values (v_tipo, 'historico', v_anio, v_numero, v_p ->> 'numero_original', v_p ->> 'asunto', v_p ->> 'remitente',
                v_p ->> 'destinatario', (v_p ->> 'dependencia_id')::bigint, v_p ->> 'observaciones',
                ((v_p ->> 'fecha')::date + time '12:00') at time zone 'America/Bogota', p_usuario_id)
        returning id, consecutivo into v_id, v_consecutivo;
        v_nuevas := v_nuevas + 1;
        v_resultados := v_resultados || jsonb_strip_nulls(jsonb_build_object('fila', v_n, 'resultado', 'nueva',
          'id', v_id, 'consecutivo', v_consecutivo, 'aviso', v_p ->> 'aviso'));
      exception when others then
        v_errores := v_errores + 1;
        v_resultados := v_resultados || jsonb_build_object('fila', v_n, 'resultado', 'error',
          'error', 'No se pudo registrar la fila: revise sus datos');
      end;
    end loop;

    if not p_confirmar then
      -- Vista previa: se deshace todo (los resultados quedan en la variable).
      raise exception 'vista previa' using errcode = 'P0002';
    end if;
  exception when sqlstate 'P0002' then
    null;
  end;

  if p_confirmar then
    perform fn_auditar('importar', 'comunicacion_historico', null, jsonb_build_object(
      'total', v_n, 'nuevas', v_nuevas, 'ya_importadas', v_ya, 'revisar', v_revisar, 'errores', v_errores));
  end if;

  return jsonb_build_object('confirmado', p_confirmar, 'total', v_n, 'nuevas', v_nuevas, 'ya_importadas', v_ya,
                            'revisar', v_revisar, 'errores', v_errores, 'filas', v_resultados);
end $$;

-- Permiso de consulta y, para el perfil Dependencia, su dependencia (null = ve todas).
create or replace function fn_historico_alcance(p_usuario_id bigint, p_recurso_id text, out permitido boolean, out dependencia_id bigint)
language plpgsql
as $$
begin
  perform fn_set_usuario_actual(p_usuario_id);
  permitido := fn_catalogo_autorizar(p_usuario_id, 'comunicaciones.consultar', 'consultar', 'comunicacion_historico', p_recurso_id);
  select case when u.perfil = 'dependencia' then coalesce(u.dependencia_id, -1) end into dependencia_id
    from usuario u where u.id = p_usuario_id;
end $$;

create or replace function fn_historico_calendario(p_usuario_id bigint, p_anio integer, p_tipo text default null)
returns jsonb
language plpgsql
as $$
declare
  v_tipo tipo_comunicacion;
  v_alcance record;
begin
  if p_anio is null or p_anio < 1990 or p_anio > extract(year from current_date)::int then
    raise exception '[campo:anio|tipo:rango] Año no válido' using errcode = '22023';
  end if;
  if nullif(trim(p_tipo), '') is not null then
    v_tipo := fn_historico_tipo(p_tipo);
    if v_tipo is null then
      raise exception '[campo:tipo|tipo:lista] Tipo no válido: use recibidas, enviadas o internas' using errcode = '22023';
    end if;
  end if;
  select * into v_alcance from fn_historico_alcance(p_usuario_id, p_anio::text);
  if not v_alcance.permitido then
    return jsonb_build_object('denegado', true, 'funcion', 'comunicaciones.consultar');
  end if;

  return jsonb_build_object(
    'anio', p_anio,
    'meses', (
      select jsonb_agg(jsonb_build_object(
               'mes', m, 'total', coalesce(c.total, 0), 'cerradas_sistema', coalesce(c.cerradas_sistema, 0),
               'importadas', coalesce(c.importadas, 0), 'futuro', make_date(p_anio, m, 1) > current_date) order by m)
        from generate_series(1, 12) m
        left join (
          select extract(month from x.fecha_recepcion at time zone 'America/Bogota')::int as mes,
                 count(*) as total,
                 count(*) filter (where x.origen <> 'historico' and x.estado = 'cerrada') as cerradas_sistema,
                 count(*) filter (where x.origen = 'historico') as importadas
            from comunicacion x
           where x.anio = p_anio and x.estado <> 'anulada'
             and (v_tipo is null or x.tipo = v_tipo)
             and (v_alcance.dependencia_id is null or x.dependencia_id = v_alcance.dependencia_id)
           group by 1
        ) c on c.mes = m),
    'anios', coalesce((
      select jsonb_agg(a order by a)
        from (select distinct x.anio::int as a from comunicacion x
               where x.estado <> 'anulada'
                 and (v_alcance.dependencia_id is null or x.dependencia_id = v_alcance.dependencia_id)) s), '[]'::jsonb));
end $$;

create or replace function fn_historico_mes(
  p_usuario_id bigint, p_anio integer, p_mes integer, p_tipo text default null,
  p_pagina integer default 1, p_limite integer default 50)
returns jsonb
language plpgsql
as $$
declare
  v_tipo tipo_comunicacion;
  v_alcance record;
  v_limite integer := least(greatest(coalesce(p_limite, 50), 1), 200);
  v_offset integer := (greatest(coalesce(p_pagina, 1), 1) - 1) * least(greatest(coalesce(p_limite, 50), 1), 200);
begin
  if p_anio is null or p_anio < 1990 or p_anio > extract(year from current_date)::int then
    raise exception '[campo:anio|tipo:rango] Año no válido' using errcode = '22023';
  end if;
  if p_mes is null or p_mes not between 1 and 12 then
    raise exception '[campo:mes|tipo:rango] Mes no válido (1 a 12)' using errcode = '22023';
  end if;
  if nullif(trim(p_tipo), '') is not null then
    v_tipo := fn_historico_tipo(p_tipo);
    if v_tipo is null then
      raise exception '[campo:tipo|tipo:lista] Tipo no válido: use recibidas, enviadas o internas' using errcode = '22023';
    end if;
  end if;
  select * into v_alcance from fn_historico_alcance(p_usuario_id, format('%s-%s', p_anio, p_mes));
  if not v_alcance.permitido then
    return jsonb_build_object('denegado', true, 'funcion', 'comunicaciones.consultar');
  end if;

  return (
    with base as (
      select x.id, x.consecutivo, x.consecutivo_original, x.tipo, x.origen, x.estado, x.asunto,
             x.remitente_nombre, x.destinatario_nombre, d.nombre as dependencia, x.fecha_recepcion
        from comunicacion x
        left join dependencia d on d.id = x.dependencia_id
       where x.anio = p_anio and x.estado <> 'anulada'
         and extract(month from x.fecha_recepcion at time zone 'America/Bogota')::int = p_mes
         and (v_tipo is null or x.tipo = v_tipo)
         and (v_alcance.dependencia_id is null or x.dependencia_id = v_alcance.dependencia_id)
    )
    select jsonb_build_object(
      'total', (select count(*) from base),
      'filas', coalesce((select jsonb_agg(to_jsonb(p) order by p.fecha_recepcion, p.consecutivo)
                           from (select * from base order by fecha_recepcion, consecutivo
                                 limit v_limite offset v_offset) p), '[]'::jsonb))
  );
end $$;

-- Solo el backend (service_role) llama estas funciones.
do $$
declare f text;
begin
  foreach f in array array[
    'fn_historico_tipo(text)', 'fn_historico_parsear(jsonb, text)',
    'fn_historico_importar(bigint, jsonb, boolean, text)', 'fn_historico_alcance(bigint, text)',
    'fn_historico_calendario(bigint, integer, text)',
    'fn_historico_mes(bigint, integer, integer, text, integer, integer)']
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
