-- =============================================================================
--  SGD · Módulo Archivo Central — 01 Base: extensiones, tipos y utilidades
--  Fuente: ia_contexto/spec/ (F-02 v1.1). PostgreSQL 15+ / Supabase.
-- =============================================================================

create extension if not exists pg_trgm;   -- búsqueda por texto parcial (RF-AC-014)
create extension if not exists unaccent;  -- búsqueda sin tildes

-- ── Tipos enumerados ─────────────────────────────────────────────────────────

-- Perfiles fijos del módulo (RF-AC-005). No hay pantalla para crear roles.
create type perfil_usuario as enum (
  'archivo_central',
  'dependencia',
  'registro_academico',
  'secretaria_general',
  'administrador'
);

create type estado_registro as enum ('activo', 'inactivo');

create type estado_documento as enum ('por_clasificar', 'clasificado', 'anulado');

create type tipo_transferencia as enum ('fisica', 'digital');

create type estado_transferencia as enum ('en_proceso', 'recibida', 'anulada');

create type tipo_carga as enum (
  'documento_individual',   -- A
  'transferencia_fisica',   -- B
  'transferencia_digital',  -- C
  'historias_academicas',   -- D
  'registro_historico',     -- E
  'app_movil'               -- F
);

create type estado_lote as enum ('pendiente', 'procesando', 'pausado', 'completado', 'con_errores', 'cancelado', 'anulado');

create type resultado_item as enum ('pendiente', 'aceptado', 'duplicado', 'error');

-- Comunicaciones (RN-AC-08, RN-AC-09)
create type tipo_comunicacion as enum ('ENT', 'SAL', 'INT');

create type estado_comunicacion as enum (
  'nueva',
  'remitida',
  'respondida_dependencia',
  'devuelta',
  'cerrada',
  'anulada'
);

create type origen_comunicacion as enum ('correo', 'manual', 'historico');

create type tipo_evento_comunicacion as enum (
  'recepcion', 'acuse_recibo', 'remision', 'respuesta_dependencia', 'devolucion',
  'respuesta_remitente', 'recordatorio', 'marcada_escalar', 'asociacion_manual',
  'anulacion', 'nota', 'error_envio'
);

-- Historias académicas (RN-AC-06, RN-AC-07)
create type estado_historia as enum ('activa', 'retirado', 'graduado');

create type nivel_academico as enum ('pregrado', 'posgrado');

create type decision_ia as enum ('pendiente', 'aceptada', 'modificada', 'descartada');

-- ── Utilidades ───────────────────────────────────────────────────────────────

-- Usuario de la operación en curso. El backend (y n8n) deben ejecutar
--   select set_config('app.usuario_id', '<id>', true);
-- al inicio de cada transacción. Si no está, la acción se atribuye al sistema.
create or replace function fn_usuario_actual()
returns bigint
language sql stable
as $$
  select nullif(current_setting('app.usuario_id', true), '')::bigint
$$;

-- Mantiene actualizado_en en cada UPDATE.
create or replace function fn_tocar_actualizado()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

-- RN-AC-12: no hay borrado físico. Se asocia como trigger BEFORE DELETE a las
-- tablas de negocio; para "eliminar" se inactiva o se anula.
create or replace function fn_bloquear_borrado()
returns trigger
language plpgsql
as $$
begin
  raise exception 'RN-AC-12: no se permite borrar registros de %. Use inactivar o anular.', tg_table_name
    using errcode = 'P0001';
end;
$$;

-- Texto normalizado para búsqueda (sin tildes, minúsculas). En Supabase la
-- extensión unaccent puede vivir en el esquema "extensions"; por eso se fija
-- el search_path de la función.
create or replace function fn_normalizar(texto text)
returns text
language sql stable parallel safe
set search_path = public, extensions
as $$
  select lower(unaccent(coalesce(texto, '')))
$$;
