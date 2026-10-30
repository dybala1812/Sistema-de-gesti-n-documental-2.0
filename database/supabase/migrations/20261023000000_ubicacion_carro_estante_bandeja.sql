-- =============================================================================
--  23 Ubicación física: Carro → Estante → Bandeja → Caja → Carpeta (D-23)
--
--  Así se ubica un documento en Archivo Central. Las columnas carro, estante y bandeja
--  ya se habían agregado a mano en el Supabase del equipo (documento, inventario_item,
--  transferencia, ubicacion_fisica) sin migración: aquí quedan versionadas, con
--  "if not exists" para que no falle donde ya están.
--  El catálogo ubicacion_fisica pasa a ser las posiciones Carro · Estante · Bandeja
--  (bodega y módulo quedan opcionales, para los registros viejos).
--  fn_documento_clasificar ahora también guarda carro, estante y bandeja.
-- =============================================================================

alter table documento        add column if not exists carro text, add column if not exists estante text, add column if not exists bandeja text;
alter table inventario_item  add column if not exists carro text, add column if not exists estante text, add column if not exists bandeja text;
alter table transferencia    add column if not exists carro text, add column if not exists estante text, add column if not exists bandeja text;
alter table ubicacion_fisica add column if not exists carro text, add column if not exists bandeja text;
alter table ubicacion_fisica alter column bodega drop not null;

comment on column documento.carro   is 'Ubicación física: carro (Carro → Estante → Bandeja → Caja → Carpeta).';
comment on column documento.estante is 'Ubicación física: estante del carro.';
comment on column documento.bandeja is 'Ubicación física: bandeja del estante.';
comment on column ubicacion_fisica.carro   is 'Posición de Archivo Central: carro.';
comment on column ubicacion_fisica.bandeja is 'Posición de Archivo Central: bandeja.';

create or replace function fn_documento_clasificar(
  p_usuario_id   bigint,
  p_documento_id bigint,
  p_datos        jsonb,
  p_clasificar   boolean default true
)
returns jsonb
language plpgsql as $$
declare
  v          documento;
  v_tipo     text;
  v_fecha    date;
  v_anio     integer;
  v_dep      bigint;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'documentos.clasificar', 'clasificar', 'documento', p_documento_id::text) then
    return jsonb_build_object('denegado', true, 'funcion', 'documentos.clasificar');
  end if;

  select * into v from documento where id = p_documento_id for update;
  if not found then
    raise exception '[campo:id|tipo:existente] El documento % no existe', p_documento_id using errcode = '22023';
  end if;
  if v.estado = 'anulado' then
    raise exception '[campo:id|tipo:estado] El documento % está anulado: no se puede clasificar', p_documento_id
      using errcode = 'P0001';
  end if;

  p_datos := coalesce(p_datos, '{}'::jsonb);

  if p_datos ? 'asunto_id' then
    v.asunto_id := nullif(p_datos->>'asunto_id', '')::bigint;
    if v.asunto_id is not null then
      select dependencia_id into v_dep from asunto where id = v.asunto_id and estado = 'activo';
      if not found then
        raise exception '[campo:asunto_id|tipo:existente] El asunto no existe o está inactivo' using errcode = '22023';
      end if;
      if v_dep <> v.dependencia_id then
        raise exception '[campo:asunto_id|tipo:valor] El asunto no pertenece a la dependencia del documento' using errcode = '22023';
      end if;
    end if;
  end if;

  if p_datos ? 'tipo' then
    v_tipo := lower(nullif(trim(p_datos->>'tipo'), ''));
    if v_tipo is not null then
      v_tipo := case
        when v_tipo like 'ent%' then 'ENT'
        when v_tipo like 'sal%' then 'SAL'
        when v_tipo like 'int%' then 'INT'
      end;
      if v_tipo is null then
        raise exception '[campo:tipo|tipo:lista] El tipo debe ser Entrada, Salida o Interno' using errcode = '22023';
      end if;
    end if;
    v.tipo_comunicacion := v_tipo::tipo_comunicacion;
  end if;

  if p_datos ? 'anio' then
    begin
      v_anio := (p_datos->>'anio')::integer;
    exception when others then
      raise exception '[campo:anio|tipo:formato] El año no es válido' using errcode = '22023';
    end;
    if v_anio is null or v_anio < 1900 or v_anio > extract(year from now())::integer then
      raise exception '[campo:anio|tipo:rango] El año debe estar entre 1900 y el año actual' using errcode = '22023';
    end if;
    v.anio := v_anio;
  end if;

  if p_datos ? 'fecha' then
    begin
      v_fecha := nullif(p_datos->>'fecha', '')::date;
    exception when others then
      raise exception '[campo:fecha|tipo:formato] La fecha no es válida' using errcode = '22023';
    end;
    if v_fecha is not null and extract(year from v_fecha)::integer <> v.anio then
      raise exception '[campo:fecha|tipo:valor] La fecha debe ser del año %', v.anio using errcode = '22023';
    end if;
    v.fecha_documento := v_fecha;
  end if;

  if p_datos ? 'consecutivo'  then v.consecutivo  := nullif(trim(p_datos->>'consecutivo'), ''); end if;
  if p_datos ? 'remitente'    then v.remitente    := nullif(trim(p_datos->>'remitente'), ''); end if;
  if p_datos ? 'destinatario' then v.destinatario := nullif(trim(p_datos->>'destinatario'), ''); end if;
  if p_datos ? 'carro'        then v.carro        := nullif(trim(p_datos->>'carro'), ''); end if;
  if p_datos ? 'estante'      then v.estante      := nullif(trim(p_datos->>'estante'), ''); end if;
  if p_datos ? 'bandeja'      then v.bandeja      := nullif(trim(p_datos->>'bandeja'), ''); end if;
  if p_datos ? 'caja'         then v.caja         := nullif(trim(p_datos->>'caja'), ''); end if;
  if p_datos ? 'carpeta'      then v.carpeta      := nullif(trim(p_datos->>'carpeta'), ''); end if;
  if p_datos ? 'observaciones' then v.observaciones := nullif(trim(p_datos->>'observaciones'), ''); end if;
  if p_datos ? 'ubicacion_id' then
    v.ubicacion_id := nullif(p_datos->>'ubicacion_id', '')::bigint;
    if v.ubicacion_id is not null and not exists (select 1 from ubicacion_fisica where id = v.ubicacion_id and estado = 'activo') then
      raise exception '[campo:ubicacion_id|tipo:existente] La ubicación no existe o está inactiva' using errcode = '22023';
    end if;
  end if;

  -- Datos que pide el F-02 para clasificar (RF-AC-011). La base exige asunto y fecha.
  if p_clasificar then
    if v.tipo_comunicacion is null then
      raise exception '[campo:tipo|tipo:obligatorio] Falta el tipo' using errcode = '22023';
    end if;
    if v.consecutivo is null then
      raise exception '[campo:consecutivo|tipo:obligatorio] Falta el consecutivo' using errcode = '22023';
    end if;
    if v.fecha_documento is null then
      raise exception '[campo:fecha|tipo:obligatorio] Falta la fecha del documento' using errcode = '22023';
    end if;
    if v.asunto_id is null then
      raise exception '[campo:asunto_id|tipo:obligatorio] Falta el asunto' using errcode = '22023';
    end if;
    if v.caja is null then
      raise exception '[campo:caja|tipo:obligatorio] Falta la caja' using errcode = '22023';
    end if;
    if v.carpeta is null then
      raise exception '[campo:carpeta|tipo:obligatorio] Falta la carpeta' using errcode = '22023';
    end if;
  end if;

  begin
    update documento
       set asunto_id = v.asunto_id, tipo_comunicacion = v.tipo_comunicacion, anio = v.anio,
           consecutivo = v.consecutivo, fecha_documento = v.fecha_documento,
           remitente = v.remitente, destinatario = v.destinatario,
           carro = v.carro, estante = v.estante, bandeja = v.bandeja,
           caja = v.caja, carpeta = v.carpeta, ubicacion_id = v.ubicacion_id,
           observaciones = v.observaciones, actualizado_en = now()
     where id = p_documento_id
    returning * into v;
  exception when unique_violation then
    -- RN-AC-11: mismo archivo (hash) en el mismo expediente dependencia + año + asunto.
    raise exception '[campo:asunto_id|tipo:duplicado] Ese expediente ya tiene un documento idéntico (mismo archivo)'
      using errcode = '22023';
  end;

  return to_jsonb(v);
end $$;

-- create or replace conserva los permisos de la migración 21 (solo service_role).

-- El catálogo de ubicaciones acepta carro, estante y bandeja (bodega y módulo, para los registros viejos).
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
    when 'ubicacion_fisica' then array['carro', 'estante', 'bandeja', 'descripcion', 'bodega', 'modulo']
    -- Los usuarios llegan de NOVA: aquí solo se asignan perfil y dependencia.
    when 'usuario' then array['dependencia_id', 'perfil']
  end
$$;

