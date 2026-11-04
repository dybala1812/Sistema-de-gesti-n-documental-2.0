-- =============================================================================
--  17 Catálogos, parámetros, plantillas y consulta de auditoría (RF-AC-001 a 006, RF-AC-023)
--
--  Antes: el backend escribía directo en las tablas de catálogos, así que la auditoría
--  quedaba sin usuario y solo el Administrador podía escribir. Ahora todo pasa por
--  funciones que:
--   - fijan el usuario que actúa (la auditoría lo registra con su id);
--   - revisan su permiso con fn_tiene_permiso y, si no lo tiene, auditan el intento
--     denegado (RN 6) y devuelven {denegado: true} en vez de escribir;
--   - solo aceptan columnas de una lista blanca (no se editan id, estado ni marcas de tiempo);
--   - nunca borran: inactivar exige motivo, que queda en el detalle de la auditoría.
--  La importación desde Excel valida cada fila contra la base real; sin confirmar no
--  escribe nada (vista previa) y al confirmar inserta las válidas y omite las erróneas.
-- =============================================================================

-- ── 1. Auditoría: motivo y id de las tablas con clave de texto ───────────────
create or replace function fn_trg_auditar_cambios()
returns trigger
language plpgsql
as $$
declare
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
  v_new jsonb := to_jsonb(new);
  v_accion text;
  v_motivo text := nullif(current_setting('app.motivo', true), '');
begin
  if tg_op = 'UPDATE' then
    -- Ignorar actualizaciones que solo tocan marcas de tiempo.
    if (v_old - 'actualizado_en' - 'ultimo_acceso_en' - 'sincronizado_en')
       = (v_new - 'actualizado_en' - 'ultimo_acceso_en' - 'sincronizado_en') then
      return null;
    end if;
    v_accion := case
      when (v_new ->> 'estado') in ('anulado', 'anulada') and (v_old ->> 'estado') is distinct from (v_new ->> 'estado') then 'anular'
      when (v_new ->> 'estado') = 'inactivo' and (v_old ->> 'estado') = 'activo' then 'inactivar'
      when (v_new ->> 'estado') = 'activo' and (v_old ->> 'estado') = 'inactivo' then 'activar'
      else 'actualizar' end;
  else
    v_accion := 'crear';
  end if;

  insert into auditoria (usuario_id, accion, recurso_tipo, recurso_id, valores_previos, valores_nuevos, detalle)
  values (fn_usuario_actual(), v_accion, tg_table_name,
          coalesce(v_new ->> 'id', v_new ->> 'clave', v_new ->> 'codigo'),
          v_old, v_new,
          case when v_motivo is null then '{}'::jsonb else jsonb_build_object('motivo', v_motivo) end);
  return null;
end;
$$;

-- ── 2. Qué tablas se administran, con qué permiso y qué columnas ─────────────
create or replace function fn_catalogo_permiso(p_tabla text)
returns text
language sql immutable
as $$
  select case p_tabla
    when 'dependencia' then 'catalogos.gestionar'
    when 'trd' then 'catalogos.gestionar'
    when 'asunto' then 'catalogos.gestionar'
    when 'tipo_documental' then 'catalogos.gestionar'
    when 'programa_academico' then 'catalogos.gestionar'
    when 'ubicacion_fisica' then 'catalogos.gestionar'
    when 'usuario' then 'usuarios.gestionar'
  end
$$;

create or replace function fn_catalogo_columnas(p_tabla text)
returns text[]
language sql immutable
as $$
  select case p_tabla
    when 'dependencia' then array['codigo', 'nombre', 'dependencia_padre_id', 'responsable', 'correo_oficial', 'nova_dependency_id']
    when 'trd' then array['codigo', 'nombre', 'descripcion', 'serie_padre_id', 'anios_gestion', 'anios_central', 'disposicion_final']
    when 'asunto' then array['dependencia_id', 'nombre', 'trd_id', 'descripcion']
    when 'tipo_documental' then array['nombre']
    when 'programa_academico' then array['codigo', 'nombre', 'nivel']
    when 'ubicacion_fisica' then array['bodega', 'estante', 'modulo', 'descripcion']
    -- Los usuarios llegan de NOVA: aquí solo se asignan perfil y dependencia.
    when 'usuario' then array['dependencia_id', 'perfil']
  end
$$;

-- Revisa el permiso; si no lo tiene, deja el intento denegado en la auditoría.
create or replace function fn_catalogo_autorizar(p_usuario_id bigint, p_funcion text, p_accion text, p_tabla text, p_id text)
returns boolean
language plpgsql
as $$
begin
  if fn_tiene_permiso(p_usuario_id, p_funcion) then
    return true;
  end if;
  perform fn_auditar(p_accion, p_tabla, p_id, jsonb_build_object('funcion', p_funcion), 'denegado');
  return false;
end $$;

-- Mensaje claro (con campo) para los errores de restricciones de la base.
create or replace function fn_catalogo_mensaje_error(p_estado text, p_restriccion text, p_columna text, p_mensaje text)
returns jsonb
language plpgsql immutable
as $$
declare
  v_etiqueta text[] := regexp_match(p_mensaje, '^\[campo:([^|\]]+)\|tipo:([^|\]]+)\]\s*(.*)$');
begin
  if v_etiqueta is not null then
    return jsonb_build_object('campo', v_etiqueta[1], 'tipo', v_etiqueta[2], 'error', v_etiqueta[3]);
  end if;
  return case p_estado
    when '23505' then case
      when p_restriccion like '%codigo%' then jsonb_build_object('campo', 'codigo', 'tipo', 'duplicado', 'error', 'Ya existe un registro con ese código')
      when p_restriccion like '%correo%' then jsonb_build_object('campo', 'correo_oficial', 'tipo', 'duplicado', 'error', 'Ya existe una dependencia con ese correo')
      when p_restriccion like '%nombre%' then jsonb_build_object('campo', 'nombre', 'tipo', 'duplicado', 'error', 'Ya existe un registro con ese nombre')
      when p_restriccion like 'ubicacion%' then jsonb_build_object('campo', 'bodega', 'tipo', 'duplicado', 'error', 'Ya existe esa combinación de bodega, estante y módulo')
      else jsonb_build_object('tipo', 'duplicado', 'error', 'Ya existe un registro con esos datos') end
    when '23503' then jsonb_build_object('campo', p_columna, 'tipo', 'existente', 'error', 'El registro relacionado no existe')
    when '23502' then jsonb_build_object('campo', p_columna, 'tipo', 'obligatorio', 'error', format('Falta %s', p_columna))
    when '23514' then case
      when p_restriccion like '%correo%' then jsonb_build_object('campo', 'correo_oficial', 'tipo', 'formato', 'error', 'El correo no tiene un formato válido')
      when p_restriccion like '%padre%' then jsonb_build_object('tipo', 'rango', 'error', 'Un registro no puede ser su propio superior')
      when p_restriccion = 'usuario_dependencia_requiere_dep' then jsonb_build_object('campo', 'dependencia_id', 'tipo', 'obligatorio', 'error', 'El perfil Dependencia exige una dependencia')
      else jsonb_build_object('tipo', 'rango', 'error', 'Un valor está fuera del rango permitido') end
    when '22P02' then jsonb_build_object('tipo', 'formato', 'error', 'Un valor no tiene el formato esperado (número o valor de la lista)')
    else jsonb_build_object('tipo', 'error', 'error', p_mensaje) end;
end $$;

-- Inserta o actualiza una fila con columnas de la lista blanca (uso interno).
create or replace function fn_catalogo_escribir(p_tabla text, p_id bigint, p_datos jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_cols text[] := fn_catalogo_columnas(p_tabla);
  v_claves text[];
  v_lista text;
  v_set text;
  v_res jsonb;
  k text;
begin
  if v_cols is null then
    raise exception '[campo:tabla|tipo:lista] Catálogo no soportado: %', p_tabla using errcode = '22023';
  end if;
  select array_agg(key) into v_claves from jsonb_object_keys(coalesce(p_datos, '{}'::jsonb)) as key;
  if v_claves is null then
    raise exception '[campo:datos|tipo:obligatorio] No se recibieron datos' using errcode = '22023';
  end if;
  foreach k in array v_claves loop
    if not k = any (v_cols) then
      raise exception '[campo:%|tipo:no_editable] El campo % no se puede editar en este catálogo', k, k using errcode = '22023';
    end if;
  end loop;

  select string_agg(quote_ident(c), ', '), string_agg(format('%1$I = r.%1$I', c), ', ')
    into v_lista, v_set from unnest(v_claves) c;

  if p_id is null then
    if p_tabla = 'usuario' then
      raise exception '[campo:id|tipo:obligatorio] Los usuarios llegan desde NOVA: solo se asignan perfil y dependencia' using errcode = '22023';
    end if;
    execute format('insert into %I (%s) select %s from jsonb_populate_record(null::%I, $1) returning to_jsonb(%I.*)',
                   p_tabla, v_lista, v_lista, p_tabla, p_tabla)
      into v_res using p_datos;
  else
    execute format('update %I t set %s, actualizado_en = now() from jsonb_populate_record(null::%I, $1) r where t.id = $2 returning to_jsonb(t.*)',
                   p_tabla, v_set, p_tabla)
      into v_res using p_datos, p_id;
    if v_res is null then
      raise exception '[campo:id|tipo:existente] El registro % no existe', p_id using errcode = '22023';
    end if;
  end if;
  return v_res;
end $$;

-- ── 3. Crear o editar un registro de catálogo ────────────────────────────────
create or replace function fn_catalogo_guardar(p_usuario_id bigint, p_tabla text, p_id bigint, p_datos jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_perm text := fn_catalogo_permiso(p_tabla);
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if v_perm is null then
    raise exception '[campo:tabla|tipo:lista] Catálogo no soportado: %', p_tabla using errcode = '22023';
  end if;
  if not fn_catalogo_autorizar(p_usuario_id, v_perm, case when p_id is null then 'crear' else 'actualizar' end, p_tabla, p_id::text) then
    return jsonb_build_object('denegado', true, 'funcion', v_perm);
  end if;
  return fn_catalogo_escribir(p_tabla, p_id, p_datos);
end $$;

-- ── 4. Activar o inactivar (nunca borrar). Inactivar exige motivo ────────────
create or replace function fn_catalogo_estado(p_usuario_id bigint, p_tabla text, p_id bigint, p_estado text, p_motivo text default null)
returns jsonb
language plpgsql
as $$
declare
  v_perm text := fn_catalogo_permiso(p_tabla);
  v_res jsonb;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if v_perm is null then
    raise exception '[campo:tabla|tipo:lista] Catálogo no soportado: %', p_tabla using errcode = '22023';
  end if;
  if p_estado not in ('activo', 'inactivo') then
    raise exception '[campo:estado|tipo:lista] El estado debe ser activo o inactivo' using errcode = '22023';
  end if;
  if p_estado = 'inactivo' and coalesce(trim(p_motivo), '') = '' then
    raise exception '[campo:motivo|tipo:obligatorio] Escriba el motivo de la inactivación' using errcode = '22023';
  end if;
  if not fn_catalogo_autorizar(p_usuario_id, v_perm, case p_estado when 'inactivo' then 'inactivar' else 'activar' end, p_tabla, p_id::text) then
    return jsonb_build_object('denegado', true, 'funcion', v_perm);
  end if;

  perform set_config('app.motivo', coalesce(trim(p_motivo), ''), true);
  execute format('update %I t set estado = $1::estado_registro, actualizado_en = now() where t.id = $2 returning to_jsonb(t.*)', p_tabla)
    into v_res using p_estado, p_id;
  perform set_config('app.motivo', '', true);
  if v_res is null then
    raise exception '[campo:id|tipo:existente] El registro % no existe', p_id using errcode = '22023';
  end if;
  return v_res;
end $$;

-- ── 5. Importar desde Excel: vista previa o confirmación ─────────────────────
-- p_filas: lista de objetos con las columnas del catálogo. Las referencias van por código:
--   dependencia → dependencia_padre_codigo · trd → serie_padre_codigo.
create or replace function fn_catalogo_importar(p_usuario_id bigint, p_tabla text, p_filas jsonb, p_confirmar boolean default false)
returns jsonb
language plpgsql
as $$
declare
  v_perm text := fn_catalogo_permiso(p_tabla);
  v_resultados jsonb := '[]'::jsonb;
  v_fila jsonb;
  v_datos jsonb;
  v_ref bigint;
  v_res jsonb;
  v_n integer := 0;
  v_ok integer := 0;
  v_estado text; v_restriccion text; v_columna text; v_mensaje text;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if p_tabla not in ('dependencia', 'trd', 'programa_academico') then
    raise exception '[campo:tabla|tipo:lista] Solo se importan dependencias, TRD y programas académicos' using errcode = '22023';
  end if;
  if jsonb_typeof(p_filas) is distinct from 'array' or jsonb_array_length(p_filas) = 0 then
    raise exception '[campo:filas|tipo:obligatorio] El archivo no tiene filas para importar' using errcode = '22023';
  end if;
  if jsonb_array_length(p_filas) > 2000 then
    raise exception '[campo:filas|tipo:rango] Máximo 2.000 filas por importación' using errcode = '22023';
  end if;
  if not fn_catalogo_autorizar(p_usuario_id, v_perm, 'importar', p_tabla, null) then
    return jsonb_build_object('denegado', true, 'funcion', v_perm);
  end if;

  begin
    for v_fila in select value from jsonb_array_elements(p_filas) loop
      v_n := v_n + 1;
      begin
        v_datos := v_fila - 'dependencia_padre_codigo' - 'serie_padre_codigo';
        -- Las celdas vacías no se envían (así se aplican los valores por defecto).
        select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_datos
          from jsonb_each(v_datos) where value <> 'null'::jsonb and value <> '""'::jsonb;
        if p_tabla = 'dependencia' and coalesce(v_fila ->> 'dependencia_padre_codigo', '') <> '' then
          select id into v_ref from dependencia where codigo = trim(v_fila ->> 'dependencia_padre_codigo');
          if v_ref is null then
            raise exception '[campo:dependencia_padre_codigo|tipo:existente] No existe la dependencia superior %', v_fila ->> 'dependencia_padre_codigo' using errcode = '22023';
          end if;
          v_datos := v_datos || jsonb_build_object('dependencia_padre_id', v_ref);
        elsif p_tabla = 'trd' and coalesce(v_fila ->> 'serie_padre_codigo', '') <> '' then
          select id into v_ref from trd where codigo = trim(v_fila ->> 'serie_padre_codigo');
          if v_ref is null then
            raise exception '[campo:serie_padre_codigo|tipo:existente] No existe la serie padre %', v_fila ->> 'serie_padre_codigo' using errcode = '22023';
          end if;
          v_datos := v_datos || jsonb_build_object('serie_padre_id', v_ref);
        end if;

        v_res := fn_catalogo_escribir(p_tabla, null, v_datos);
        v_ok := v_ok + 1;
        v_resultados := v_resultados || jsonb_build_object('fila', v_n, 'ok', true, 'id', v_res -> 'id');
      exception when others then
        get stacked diagnostics v_estado = returned_sqlstate, v_restriccion = constraint_name,
                                v_columna = column_name, v_mensaje = message_text;
        v_resultados := v_resultados || (jsonb_build_object('fila', v_n, 'ok', false)
                        || fn_catalogo_mensaje_error(v_estado, v_restriccion, v_columna, v_mensaje));
      end;
    end loop;

    if not p_confirmar then
      -- Vista previa: se deshacen todas las filas (los resultados quedan en la variable).
      raise exception 'vista previa' using errcode = 'P0002';
    end if;
  exception when sqlstate 'P0002' then
    null;
  end;

  return jsonb_build_object(
    'confirmado', p_confirmar, 'total', v_n, 'validas', v_ok, 'con_error', v_n - v_ok, 'filas', v_resultados);
end $$;

-- ── 6. Parámetros (RF-AC-006) ────────────────────────────────────────────────
create or replace function fn_parametro_guardar(p_usuario_id bigint, p_clave text, p_valor text)
returns jsonb
language plpgsql
as $$
declare
  v parametro;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'parametros.gestionar', 'actualizar', 'parametro', p_clave) then
    return jsonb_build_object('denegado', true, 'funcion', 'parametros.gestionar');
  end if;
  select * into v from parametro where clave = p_clave for update;
  if not found then
    raise exception '[campo:clave|tipo:existente] El parámetro % no existe', p_clave using errcode = '22023';
  end if;
  if coalesce(trim(p_valor), '') = '' then
    raise exception '[campo:valor|tipo:obligatorio] El valor no puede quedar vacío' using errcode = '22023';
  end if;
  begin
    update parametro set valor = trim(p_valor), actualizado_en = now() where clave = p_clave returning * into v;
  exception when check_violation then
    raise exception '[campo:valor|tipo:rango] %', case
      when v.tipo in ('entero', 'decimal') and (v.minimo is not null or v.maximo is not null)
        then format('El valor debe ser un número %s entre %s y %s', case v.tipo when 'entero' then 'entero' else '' end,
                    coalesce(v.minimo::text, '−∞'), coalesce(v.maximo::text, '∞'))
      when v.tipo = 'entero' then 'El valor debe ser un número entero'
      when v.tipo = 'decimal' then 'El valor debe ser un número'
      when v.tipo = 'booleano' then 'El valor debe ser true o false'
      else 'El valor no es válido' end
      using errcode = '22023';
  end;
  return to_jsonb(v);
end $$;

-- ── 7. Plantillas de correo (RF-AC-006) ──────────────────────────────────────
create or replace function fn_plantilla_guardar(p_usuario_id bigint, p_codigo text, p_asunto text, p_cuerpo text, p_restablecer boolean default false)
returns jsonb
language plpgsql
as $$
declare
  v plantilla_correo;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'plantillas.gestionar', 'actualizar', 'plantilla_correo', p_codigo) then
    return jsonb_build_object('denegado', true, 'funcion', 'plantillas.gestionar');
  end if;
  select * into v from plantilla_correo where codigo = p_codigo for update;
  if not found then
    raise exception '[campo:codigo|tipo:existente] La plantilla % no existe', p_codigo using errcode = '22023';
  end if;
  if p_restablecer then
    update plantilla_correo set cuerpo = cuerpo_original, actualizado_en = now() where codigo = p_codigo returning * into v;
    return to_jsonb(v);
  end if;
  if coalesce(trim(p_asunto), '') = '' then
    raise exception '[campo:asunto|tipo:obligatorio] El asunto no puede quedar vacío' using errcode = '22023';
  end if;
  if coalesce(trim(p_cuerpo), '') = '' then
    raise exception '[campo:cuerpo|tipo:obligatorio] El cuerpo no puede quedar vacío' using errcode = '22023';
  end if;
  update plantilla_correo set asunto = trim(p_asunto), cuerpo = p_cuerpo, actualizado_en = now()
   where codigo = p_codigo returning * into v;
  return to_jsonb(v);
end $$;

-- ── 8. Consultar la auditoría (RF-AC-023) ────────────────────────────────────
create or replace function fn_auditoria_consultar(
  p_usuario_id bigint,
  p_desde timestamptz default null,
  p_hasta timestamptz default null,
  p_usuario bigint default null,
  p_accion text default null,
  p_recurso_tipo text default null,
  p_recurso_id text default null,
  p_resultado text default null,
  p_pagina integer default 1,
  p_limite integer default 50
)
returns jsonb
language plpgsql
as $$
declare
  v_limite integer := least(greatest(coalesce(p_limite, 50), 1), 200);
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_total bigint;
  v_filas jsonb;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'auditoria.consultar', 'consultar', 'auditoria', null) then
    return jsonb_build_object('denegado', true, 'funcion', 'auditoria.consultar');
  end if;

  select count(*) into v_total from auditoria a
   where (p_desde is null or a.fecha >= p_desde) and (p_hasta is null or a.fecha < p_hasta)
     and (p_usuario is null or a.usuario_id = p_usuario) and (p_accion is null or a.accion = p_accion)
     and (p_recurso_tipo is null or a.recurso_tipo = p_recurso_tipo) and (p_recurso_id is null or a.recurso_id = p_recurso_id)
     and (p_resultado is null or a.resultado = p_resultado);

  select coalesce(jsonb_agg(f order by f.fecha desc, f.id desc), '[]'::jsonb) into v_filas from (
    select a.id, a.fecha, a.accion, a.recurso_tipo, a.recurso_id, a.resultado, a.detalle,
           a.valores_previos, a.valores_nuevos, a.usuario_id,
           nullif(trim(coalesce(u.nombre, '') || ' ' || coalesce(u.apellido, '')), '') as usuario
      from auditoria a left join usuario u on u.id = a.usuario_id
     where (p_desde is null or a.fecha >= p_desde) and (p_hasta is null or a.fecha < p_hasta)
       and (p_usuario is null or a.usuario_id = p_usuario) and (p_accion is null or a.accion = p_accion)
       and (p_recurso_tipo is null or a.recurso_tipo = p_recurso_tipo) and (p_recurso_id is null or a.recurso_id = p_recurso_id)
       and (p_resultado is null or a.resultado = p_resultado)
     order by a.fecha desc, a.id desc
     limit v_limite offset (v_pagina - 1) * v_limite
  ) f;

  return jsonb_build_object('datos', v_filas, 'total', v_total, 'pagina', v_pagina, 'limite', v_limite,
                            'totalPaginas', ceil(v_total::numeric / v_limite));
end $$;

-- ── Permisos: solo el backend (service_role) ─────────────────────────────────
do $$
declare
  f text;
begin
  foreach f in array array[
    'fn_catalogo_permiso(text)', 'fn_catalogo_columnas(text)', 'fn_catalogo_autorizar(bigint, text, text, text, text)',
    'fn_catalogo_mensaje_error(text, text, text, text)', 'fn_catalogo_escribir(text, bigint, jsonb)',
    'fn_catalogo_guardar(bigint, text, bigint, jsonb)', 'fn_catalogo_estado(bigint, text, bigint, text, text)',
    'fn_catalogo_importar(bigint, text, jsonb, boolean)', 'fn_parametro_guardar(bigint, text, text)',
    'fn_plantilla_guardar(bigint, text, text, text, boolean)',
    'fn_auditoria_consultar(bigint, timestamptz, timestamptz, bigint, text, text, text, text, integer, integer)']
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

notify pgrst, 'reload schema';
