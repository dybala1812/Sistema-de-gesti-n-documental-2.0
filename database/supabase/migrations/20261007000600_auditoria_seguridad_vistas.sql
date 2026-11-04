-- =============================================================================
--  06 Auditoría, permisos, seguridad (RLS) y vistas
--  RF-AC-023, RF-AC-024 · RN-AC-12 · RNF-AC-02
-- =============================================================================

-- ── Auditoría inmutable (RF-AC-023) ─────────────────────────────────────────
create table auditoria (
  id              bigint generated always as identity primary key,
  fecha           timestamptz not null default now(),
  usuario_id      bigint references usuario(id),            -- null = sistema / n8n
  accion          text not null,                            -- crear, actualizar, anular, consultar, descargar, denegado, iniciar_sesion…
  recurso_tipo    text not null,                            -- tabla o tipo de recurso
  recurso_id      text,
  valores_previos jsonb,
  valores_nuevos  jsonb,
  resultado       text not null default 'ok' check (resultado in ('ok', 'denegado', 'error')),
  detalle         jsonb not null default '{}'::jsonb,
  ip              inet
);
create index auditoria_fecha_idx on auditoria (fecha desc);
create index auditoria_usuario_idx on auditoria (usuario_id, fecha desc);
create index auditoria_recurso_idx on auditoria (recurso_tipo, recurso_id);
comment on table auditoria is 'RF-AC-023. Append-only: no se puede editar ni borrar (ni siquiera el Administrador).';

create or replace function fn_auditoria_inmutable()
returns trigger
language plpgsql
as $$
begin
  raise exception 'RF-AC-023: la auditoría no se puede editar ni borrar' using errcode = 'P0001';
end;
$$;

create trigger auditoria_sin_update   before update   on auditoria for each row       execute function fn_auditoria_inmutable();
create trigger auditoria_sin_delete   before delete   on auditoria for each row       execute function fn_auditoria_inmutable();
create trigger auditoria_sin_truncate before truncate on auditoria for each statement execute function fn_auditoria_inmutable();

-- Registro explícito: consultas, descargas, intentos denegados, decisiones de IA.
-- El backend lo llama en cada acción que no es un INSERT/UPDATE de tabla.
create or replace function fn_auditar(
  p_accion text, p_recurso_tipo text, p_recurso_id text,
  p_detalle jsonb default '{}'::jsonb, p_resultado text default 'ok', p_ip inet default null
)
returns void
language sql
as $$
  insert into auditoria (usuario_id, accion, recurso_tipo, recurso_id, detalle, resultado, ip)
  values (fn_usuario_actual(), p_accion, p_recurso_tipo, p_recurso_id, coalesce(p_detalle, '{}'::jsonb), p_resultado, p_ip)
$$;

-- Auditoría automática de cambios (valores previos y nuevos).
create or replace function fn_trg_auditar_cambios()
returns trigger
language plpgsql
as $$
declare
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
  v_new jsonb := to_jsonb(new);
  v_accion text;
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

  insert into auditoria (usuario_id, accion, recurso_tipo, recurso_id, valores_previos, valores_nuevos)
  values (fn_usuario_actual(), v_accion, tg_table_name, v_new ->> 'id', v_old, v_new);
  return null;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'dependencia','trd','asunto','tipo_documental','programa_academico','ubicacion_fisica',
    'usuario','parametro','plantilla_correo',
    'lote_carga','transferencia','inventario_item','documento','sugerencia_ia',
    'comunicacion','correo_sin_asociar',
    'estudiante','historia_academica','historia_documento']
  loop
    execute format('create trigger %I after insert or update on %I for each row execute function fn_trg_auditar_cambios()', t || '_auditar', t);
  end loop;
end $$;

-- ── Permisos por perfil y dependencia (RF-AC-023) ───────────────────────────
-- La autorización se aplica en el backend con estas funciones (el usuario no
-- tiene sesión de Supabase porque no hay login propio).

-- ¿Puede el usuario ver documentos/transferencias de esta dependencia?
create or replace function fn_puede_ver_dependencia(p_usuario_id bigint, p_dependencia_id bigint)
returns boolean
language sql stable
as $$
  select exists (
    select 1 from usuario u
    where u.id = p_usuario_id
      and fn_usuario_puede_ingresar(u.id)
      and (u.perfil in ('archivo_central', 'secretaria_general', 'administrador')
           or (u.perfil = 'dependencia' and u.dependencia_id = p_dependencia_id))
  )
$$;

-- ¿Puede ver una historia académica? RA solo activas (RN-AC-06); AC y SG todas.
create or replace function fn_puede_ver_historia(p_usuario_id bigint, p_historia_id bigint)
returns boolean
language sql stable
as $$
  select exists (
    select 1
    from usuario u, historia_academica h
    where u.id = p_usuario_id and h.id = p_historia_id
      and fn_usuario_puede_ingresar(u.id)
      and (u.perfil in ('archivo_central', 'secretaria_general')
           or (u.perfil = 'registro_academico' and h.estado = 'activa'))
  )
$$;

-- Matriz de funciones por perfil (F-02 §2.3). El backend consulta
-- fn_tiene_permiso(usuario, 'funcion') antes de cada acción.
create table permiso_perfil (
  perfil   perfil_usuario not null,
  funcion  text not null,
  primary key (perfil, funcion)
);

create or replace function fn_tiene_permiso(p_usuario_id bigint, p_funcion text)
returns boolean
language sql stable
as $$
  select exists (
    select 1 from usuario u join permiso_perfil p on p.perfil = u.perfil
    where u.id = p_usuario_id and p.funcion = p_funcion and fn_usuario_puede_ingresar(u.id)
  )
$$;

-- ── Seguridad a nivel de base de datos (RNF-AC-02) ──────────────────────────
-- No hay login de Supabase: nadie accede por la API pública (anon/authenticated).
-- El backend y n8n se conectan con una credencial de servicio (fuera del repo).
-- RLS activado sin políticas = acceso denegado por defecto a la API pública.
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;

  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on all tables in schema public from anon';
    execute 'revoke all on all sequences in schema public from anon';
    execute 'revoke execute on all functions in schema public from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on all tables in schema public from authenticated';
    execute 'revoke all on all sequences in schema public from authenticated';
    execute 'revoke execute on all functions in schema public from authenticated';
  end if;
end $$;

-- ── Vistas ───────────────────────────────────────────────────────────────────

-- Asuntos con su código TRD (compatible con el flujo n8n de clasificación IA).
create view v_asuntos as
select a.id, a.dependencia_id, d.codigo as codigo_dependencia, d.nombre as dependencia,
       a.nombre as asunto, t.codigo as codigo_trd,
       coalesce(a.descripcion, t.descripcion) as descripcion,
       (a.estado = 'activo') as activo
from asunto a
join dependencia d on d.id = a.dependencia_id
join trd t on t.id = a.trd_id;

-- Árbol Dependencia → Año → Asunto con contadores (RF-AC-013).
create view v_arbol_archivo as
select d.id as dependencia_id, d.codigo as codigo_dependencia, d.nombre as dependencia,
       doc.anio, a.id as asunto_id, a.nombre as asunto, t.codigo as codigo_trd,
       count(*) as documentos
from documento doc
join dependencia d on d.id = doc.dependencia_id
join asunto a on a.id = doc.asunto_id
join trd t on t.id = a.trd_id
where doc.estado = 'clasificado'
group by d.id, d.codigo, d.nombre, doc.anio, a.id, a.nombre, t.codigo;

-- Árbol de historias Estado → Año → Nivel → Programa (RF-AC-020).
create view v_arbol_historias as
select h.estado, h.anio, p.nivel, p.id as programa_id, p.nombre as programa, count(*) as estudiantes
from historia_academica h
join programa_academico p on p.id = h.programa_id
group by h.estado, h.anio, p.nivel, p.id, p.nombre;

-- Bandeja de comunicaciones con días transcurridos y vencimiento (mockup Bandeja).
create view v_bandeja_comunicaciones as
select c.id, c.consecutivo, c.tipo, c.estado, c.fecha_recepcion,
       c.remitente_nombre, c.remitente_correo, c.asunto,
       c.dependencia_id, d.nombre as dependencia,
       c.fecha_limite, c.n_recordatorios, c.por_escalar,
       (current_date - c.fecha_recepcion::date) as dias_desde_recepcion,
       (c.estado in ('remitida', 'devuelta') and c.fecha_limite < current_date) as vencida,
       (select count(*) from comunicacion_adjunto ad where ad.comunicacion_id = c.id) as adjuntos
from comunicacion c
left join dependencia d on d.id = c.dependencia_id;

-- Dependencias que aún no transfieren el año que les corresponde (año actual − 2).
create view v_dependencias_pendientes_transferir as
select d.id as dependencia_id, d.codigo, d.nombre,
       (extract(year from current_date)::integer - coalesce(fn_parametro_entero('anios_minimos_transferencia'), 2)) as anio_que_corresponde
from dependencia d
where d.estado = 'activo'
  and not exists (
    select 1 from transferencia t
    where t.dependencia_id = d.id
      and t.estado <> 'anulada'
      and t.anio = extract(year from current_date)::integer - coalesce(fn_parametro_entero('anios_minimos_transferencia'), 2)
  );

-- Indicadores de la pantalla Inicio.
create view v_inicio_indicadores as
select
  (select count(*) from documento where estado = 'por_clasificar')               as documentos_por_clasificar,
  (select count(*) from transferencia where estado = 'en_proceso')               as transferencias_en_proceso,
  (select count(*) from historia_academica)                                       as historias_cargadas,
  (select count(*) from comunicacion where estado = 'nueva')                     as comunicaciones_nuevas,
  (select count(*) from comunicacion where estado in ('remitida', 'devuelta') and fecha_limite < current_date) as comunicaciones_vencidas,
  (select count(*) from v_dependencias_pendientes_transferir)                    as dependencias_pendientes;

-- Las vistas tampoco se exponen a la API pública.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on v_asuntos, v_arbol_archivo, v_arbol_historias, v_bandeja_comunicaciones, v_dependencias_pendientes_transferir, v_inicio_indicadores from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on v_asuntos, v_arbol_archivo, v_arbol_historias, v_bandeja_comunicaciones, v_dependencias_pendientes_transferir, v_inicio_indicadores from authenticated';
  end if;
end $$;
