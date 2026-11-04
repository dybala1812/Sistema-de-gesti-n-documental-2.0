-- =============================================================================
--  31 Transferencias: lo que existía solo en el Supabase del equipo (D-29, I-20)
--
--  Para instalar la base en un PostgreSQL local (producción) desde las migraciones, sin el
--  Supabase del equipo. Ahí se habían creado a mano, sin migración:
--    - transferencia.contenido y transferencia.ubicacion_texto
--    - inventario_item.docs e inventario_item.descripcion
--    - el valor 'ambas' del tipo de transferencia
--    - la función registrar_transferencia(p jsonb), que usa POST /api/transferencias
--  Todo es "si no existe": en el Supabase del equipo no cambia nada.
--
--  registrar_transferencia está RECONSTRUIDA a partir de lo que el backend le envía y espera
--  (app/api/transferencias/route.ts). Si se exporta la original de Supabase
--  (select pg_get_functiondef('registrar_transferencia'::regproc)), debe reemplazar a esta.
-- =============================================================================

alter table transferencia
  add column if not exists contenido       text,
  add column if not exists ubicacion_texto text;

alter table inventario_item
  add column if not exists docs        integer,
  add column if not exists descripcion text;

alter type tipo_transferencia add value if not exists 'ambas';

do $instalar$
begin
  if to_regprocedure('registrar_transferencia(jsonb)') is not null then
    return;   -- ya existe (Supabase del equipo): se respeta la original
  end if;

  execute $crear$
create function registrar_transferencia(p jsonb)
returns jsonb
language plpgsql
as $cuerpo$
declare
  v_usuario  bigint := nullif(p ->> 'usuario_id', '')::bigint;
  v_texto    text := trim(coalesce(p ->> 'dependencia', ''));
  v_dep      bigint;
  v_anio     integer;
  v_tipo     text := trim(coalesce(p ->> 'tipo', ''));
  v_maximo   integer := extract(year from current_date)::integer - coalesce(fn_parametro_entero('anios_minimos_transferencia'), 2);
  v_filas    jsonb := coalesce(p -> 'carpetas', '[]'::jsonb);
  v_fila     jsonb;
  v_n        integer;
  v_caja     text;
  v_ini      date;
  v_fin      date;
  v_prefijo  text := 'TR-' || extract(year from current_date)::integer || '-';
  v_codigo   text;
  v_id       bigint;
begin
  if v_usuario is not null then
    perform fn_set_usuario_actual(v_usuario);
  end if;

  -- La dependencia llega por nombre (lista de la pantalla); también se acepta código o id.
  select d.id into v_dep
    from dependencia d
   where d.estado = 'activo'
     and (lower(d.nombre) = lower(v_texto) or d.codigo = v_texto or d.id::text = v_texto)
   order by (lower(d.nombre) = lower(v_texto)) desc
   limit 1;
  if v_dep is null then
    raise exception 'La dependencia no es válida' using errcode = 'P0001';
  end if;

  if coalesce(p ->> 'anio', '') !~ '^\d{4}$' then
    raise exception 'El año de los documentos no es válido' using errcode = 'P0001';
  end if;
  v_anio := (p ->> 'anio')::integer;
  -- RN-AC-03: se transfiere hasta año actual − años mínimos.
  if v_anio > v_maximo then
    raise exception 'RN-AC-03: en % solo se pueden transferir documentos hasta %; la transferencia es de %.',
      extract(year from current_date)::integer, v_maximo, v_anio using errcode = 'P0001';
  end if;

  if v_tipo not in ('fisica', 'digital', 'ambas') then
    raise exception 'Tipo de entrega no válido' using errcode = 'P0001';
  end if;
  if trim(coalesce(p ->> 'contenido', '')) = '' then
    raise exception 'Falta el contenido de la transferencia' using errcode = 'P0001';
  end if;
  if trim(coalesce(p ->> 'responsable', '')) = '' then
    raise exception 'Falta el funcionario que entrega' using errcode = 'P0001';
  end if;
  if jsonb_typeof(v_filas) <> 'array' or jsonb_array_length(v_filas) = 0 then
    raise exception 'El inventario está vacío: falta al menos una caja' using errcode = 'P0001';
  end if;

  -- Código TR-AAAA-NNN (año del registro), sin choques entre registros simultáneos.
  perform pg_advisory_xact_lock(hashtext('registrar_transferencia'));
  select v_prefijo || lpad((coalesce(max(substring(t.codigo from length(v_prefijo) + 1)::integer), 0) + 1)::text, 3, '0')
    into v_codigo
    from transferencia t
   where t.codigo like v_prefijo || '%' and substring(t.codigo from length(v_prefijo) + 1) ~ '^\d+$';

  insert into transferencia (codigo, dependencia_id, anio, tipo, funcionario_entrega, contenido, ubicacion_texto, registrado_por)
  values (v_codigo, v_dep, v_anio, v_tipo::tipo_transferencia, trim(p ->> 'responsable'), trim(p ->> 'contenido'),
          nullif(trim(coalesce(p ->> 'ubicacion', '')), ''), v_usuario)
  returning id into v_id;

  for v_fila, v_n in select e.valor, e.n from jsonb_array_elements(v_filas) with ordinality as e(valor, n) loop
    v_caja := nullif(trim(coalesce(v_fila ->> 'caja', '')), '');
    if v_caja is null then
      raise exception 'Fila %: falta la caja', v_n using errcode = 'P0001';
    end if;
    begin
      v_ini := nullif(coalesce(v_fila ->> 'fechaInicial', v_fila ->> 'fecha_inicial'), '')::date;
      v_fin := nullif(coalesce(v_fila ->> 'fechaFinal', v_fila ->> 'fecha_final'), '')::date;
    exception when others then
      raise exception 'Fila % (caja %): fecha no válida', v_n, v_caja using errcode = 'P0001';
    end;
    if v_ini is not null and v_fin is not null and v_fin < v_ini then
      raise exception 'Fila % (caja %): la fecha final es anterior a la inicial', v_n, v_caja using errcode = 'P0001';
    end if;

    insert into inventario_item (transferencia_id, fila_origen, caja, carpeta_tomo, asunto_texto,
                                 fecha_inicial, fecha_final, folios, docs, descripcion)
    values (v_id, v_n, v_caja,
            nullif(trim(coalesce(v_fila ->> 'carpeta', '')), ''),
            nullif(trim(coalesce(v_fila ->> 'asunto', '')), ''),
            v_ini, v_fin,
            nullif(v_fila ->> 'folios', '')::numeric::integer,
            nullif(v_fila ->> 'docs', '')::numeric::integer,
            nullif(trim(coalesce(v_fila ->> 'descripcion', '')), ''));
  end loop;

  return jsonb_build_object('id', v_id, 'codigo', v_codigo);
end
$cuerpo$
$crear$;

  revoke execute on function registrar_transferencia(jsonb) from public;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke execute on function registrar_transferencia(jsonb) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke execute on function registrar_transferencia(jsonb) from authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function registrar_transferencia(jsonb) to service_role;
  end if;
end $instalar$;

notify pgrst, 'reload schema';
