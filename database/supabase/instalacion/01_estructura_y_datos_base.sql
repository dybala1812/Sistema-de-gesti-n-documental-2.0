-- SGD · Archivo Central — instalación en un proyecto Supabase NUEVO (vacío).
-- Generado con database/scripts/armar_instalacion.sh el 2026-10-30. No editar a mano.
-- Ejecutar UNA sola vez en Supabase → SQL Editor. Contiene todas las migraciones y seed.sql.


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000100_base.sql
-- ═════════════════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000200_catalogos_y_usuarios.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  02 Catálogos y usuarios (RF-AC-001 a RF-AC-006)
-- =============================================================================

-- ── Dependencias (RF-AC-001) ────────────────────────────────────────────────
create table dependencia (
  id                  bigint generated always as identity primary key,
  codigo              text not null unique,                 -- ej. '100' Rectoría
  nombre              text not null,
  dependencia_padre_id bigint references dependencia(id),
  responsable         text,
  correo_oficial      text not null,                        -- para remitir y reconocer respuestas
  -- Enlace con NOVA: la dependencia del perfil de NOVA (UUID) se mapea aquí.
  nova_dependency_id  uuid unique,
  estado              estado_registro not null default 'activo',
  creado_en           timestamptz not null default now(),
  actualizado_en      timestamptz not null default now(),
  constraint dependencia_no_es_su_padre check (dependencia_padre_id is null or dependencia_padre_id <> id),
  constraint dependencia_correo_formato check (correo_oficial ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);
create unique index dependencia_correo_unico on dependencia (lower(correo_oficial));
comment on table dependencia is 'RF-AC-001. Primer nivel del archivo (RN-AC-01). Con documentos/comunicaciones solo se inactiva.';

-- ── TRD: series y subseries (RF-AC-002) ─────────────────────────────────────
create table trd (
  id                 bigint generated always as identity primary key,
  codigo             text not null unique,                  -- ej. '110.01'; identificador de clasificación
  nombre             text not null,
  descripcion        text,                                  -- alimenta la IA (RF-AC-012)
  serie_padre_id     bigint references trd(id),             -- null = serie; con valor = subserie
  anios_gestion      smallint not null default 2 check (anios_gestion >= 0),
  anios_central      smallint not null check (anios_central >= 0),
  disposicion_final  text not null check (disposicion_final in ('conservacion_total', 'eliminacion', 'seleccion', 'digitalizacion')),
  estado             estado_registro not null default 'activo',
  creado_en          timestamptz not null default now(),
  actualizado_en     timestamptz not null default now()
);
comment on table trd is 'RF-AC-002. Tabla de Retención Documental. Con documentos asociados solo se inactiva.';

-- ── Asuntos por dependencia (RF-AC-003, RN-AC-02) ───────────────────────────
create table asunto (
  id              bigint generated always as identity primary key,
  dependencia_id  bigint not null references dependencia(id),
  nombre          text not null,                            -- "asunto" = serie documental para el cliente
  trd_id          bigint not null references trd(id),       -- RN-AC-02: todo asunto tiene código TRD
  descripcion     text,                                     -- alimenta la IA (RF-AC-012)
  estado          estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
-- El mismo nombre puede repetirse entre dependencias, no dentro de una.
create unique index asunto_nombre_por_dependencia on asunto (dependencia_id, lower(nombre));
create index asunto_trd_idx on asunto (trd_id);

-- ── Catálogos de apoyo (RF-AC-004) ──────────────────────────────────────────
create table tipo_documental (
  id              bigint generated always as identity primary key,
  nombre          text not null,
  estado          estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
create unique index tipo_documental_nombre_unico on tipo_documental (lower(nombre));

create table programa_academico (
  id              bigint generated always as identity primary key,
  codigo          text unique,
  nombre          text not null,
  nivel           nivel_academico not null,
  estado          estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
create unique index programa_nombre_nivel_unico on programa_academico (lower(nombre), nivel);

-- Opcional: se usa solo si el cliente lo confirma (P-08).
create table ubicacion_fisica (
  id              bigint generated always as identity primary key,
  bodega          text not null,
  estante         text,
  modulo          text,
  descripcion     text,
  estado          estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  unique (bodega, estante, modulo)
);

-- ── Usuarios (RF-AC-005) — sin login propio ─────────────────────────────────
-- El módulo NO autentica: el usuario llega autenticado desde NOVA. El backend
-- valida el token de NOVA (GET /api/users/perfil/ de NOVA) y sincroniza aquí
-- una copia de sus datos con fn_sincronizar_usuario_nova(). El perfil del
-- módulo lo asigna un Administrador; mientras sea NULL el usuario no tiene
-- acceso al módulo.
create table usuario (
  id                  bigint generated always as identity primary key,
  nova_user_id        uuid not null unique,                 -- UsuarioAPI.id de NOVA
  email               text not null,
  username            text,
  nombre              text not null,
  apellido            text not null default '',
  tipo_documento      text,
  cedula              text,
  telefono            text,
  -- Datos de NOVA tal como llegaron (dependencia, roles, perfil_tipo, etc.).
  nova_dependency_id  uuid,
  nova_roles          text[] not null default '{}',
  nova_is_staff       boolean not null default false,
  nova_activo         boolean not null default true,
  datos_nova          jsonb not null default '{}'::jsonb,
  -- Datos propios del módulo.
  dependencia_id      bigint references dependencia(id),    -- mapeada desde NOVA o asignada por ADM
  perfil              perfil_usuario,                       -- NULL = pendiente de asignación
  estado              estado_registro not null default 'activo',
  primer_acceso_en    timestamptz not null default now(),
  ultimo_acceso_en    timestamptz not null default now(),
  sincronizado_en     timestamptz not null default now(),
  creado_en           timestamptz not null default now(),
  actualizado_en      timestamptz not null default now(),
  constraint usuario_dependencia_requiere_dep check (perfil is distinct from 'dependencia' or dependencia_id is not null)
);
create index usuario_email_idx on usuario (lower(email));
comment on table usuario is 'RF-AC-005. Copia sincronizada del usuario de NOVA + perfil del módulo. Sin contraseña: no hay login propio.';

-- ── Parámetros (RF-AC-006) ──────────────────────────────────────────────────
create table parametro (
  clave           text primary key,
  valor           text not null,
  tipo            text not null check (tipo in ('entero', 'decimal', 'texto', 'lista', 'booleano')),
  descripcion     text not null,
  minimo          numeric,
  maximo          numeric,
  actualizado_en  timestamptz not null default now(),
  -- CASE garantiza el orden de evaluación: solo se convierte a número si el texto es numérico.
  constraint parametro_rango check (
    case
      when tipo = 'entero'  and valor !~ '^-?[0-9]+$' then false
      when tipo = 'decimal' and valor !~ '^-?[0-9]+(\.[0-9]+)?$' then false
      when tipo in ('entero', 'decimal') then
        (minimo is null or valor::numeric >= minimo) and (maximo is null or valor::numeric <= maximo)
      when tipo = 'booleano' then valor in ('true', 'false')
      else true
    end
  )
);

create or replace function fn_parametro_entero(p_clave text)
returns integer
language sql stable
as $$
  select valor::integer from parametro where clave = p_clave
$$;

-- ── Plantillas de correo (RF-AC-006) ────────────────────────────────────────
create table plantilla_correo (
  codigo          text primary key check (codigo in ('acuse_recibo', 'remision', 'devolucion', 'respuesta', 'recordatorio', 'resumen')),
  nombre          text not null,
  asunto          text not null,
  cuerpo          text not null,                            -- admite {consecutivo} {nombre} {asunto} {dependencia} {fecha} {plazo} {respuesta}
  cuerpo_original text not null,                            -- para "Restablecer texto original"
  actualizado_en  timestamptz not null default now()
);

-- ── Días festivos (para días hábiles en recordatorios, RF-AC-018 / P-15) ────
create table dia_festivo (
  fecha        date primary key,
  descripcion  text not null
);

create or replace function fn_es_dia_habil(p_fecha date)
returns boolean
language sql stable
as $$
  select extract(isodow from p_fecha) < 6
     and not exists (select 1 from dia_festivo where fecha = p_fecha)
$$;

-- Suma n días hábiles a una fecha.
create or replace function fn_sumar_dias_habiles(p_desde date, p_dias integer)
returns date
language plpgsql stable
as $$
declare
  v_fecha date := p_desde;
  v_contados integer := 0;
begin
  while v_contados < p_dias loop
    v_fecha := v_fecha + 1;
    if fn_es_dia_habil(v_fecha) then
      v_contados := v_contados + 1;
    end if;
  end loop;
  return v_fecha;
end;
$$;

-- Días hábiles transcurridos entre dos fechas (excluye la inicial).
create or replace function fn_dias_habiles_entre(p_desde date, p_hasta date)
returns integer
language sql stable
as $$
  select count(*)::integer
  from generate_series(p_desde + 1, p_hasta, interval '1 day') d
  where fn_es_dia_habil(d::date)
$$;

-- ── Sincronización del usuario desde NOVA ───────────────────────────────────
-- Recibe el JSON de GET /api/users/perfil/ de NOVA (UsuarioAPI) YA VALIDADO
-- por el backend contra NOVA. Nunca llamar con datos enviados por el navegador
-- sin validar el token. Devuelve la fila del usuario.
-- La dependencia de NOVA puede venir como objeto {id, name, code, email} o
-- como UUID (string); se mapea por nova_dependency_id y, si no, por código.
create or replace function fn_sincronizar_usuario_nova(p_perfil jsonb)
returns usuario
language plpgsql
as $$
declare
  v_dep        jsonb := p_perfil -> 'dependency';
  v_dep_uuid   uuid;
  v_dep_code   text;
  v_dep_id     bigint;
  v_usuario    usuario;
begin
  if p_perfil ->> 'id' is null or p_perfil ->> 'email' is null then
    raise exception 'Perfil de NOVA inválido: faltan id o email';
  end if;

  if jsonb_typeof(v_dep) = 'object' then
    v_dep_uuid := nullif(v_dep ->> 'id', '')::uuid;
    v_dep_code := nullif(v_dep ->> 'code', '');
  elsif jsonb_typeof(v_dep) = 'string' then
    v_dep_uuid := nullif(p_perfil ->> 'dependency', '')::uuid;
  end if;

  select id into v_dep_id from dependencia where nova_dependency_id = v_dep_uuid;
  if v_dep_id is null and v_dep_code is not null then
    select id into v_dep_id from dependencia where codigo = v_dep_code;
    -- Primer encuentro por código: guardar el enlace para la próxima vez.
    if v_dep_id is not null and v_dep_uuid is not null then
      update dependencia set nova_dependency_id = v_dep_uuid
       where id = v_dep_id and nova_dependency_id is null;
    end if;
  end if;

  insert into usuario as u (
    nova_user_id, email, username, nombre, apellido, tipo_documento, cedula, telefono,
    nova_dependency_id, nova_roles, nova_is_staff, nova_activo, datos_nova, dependencia_id
  ) values (
    (p_perfil ->> 'id')::uuid,
    p_perfil ->> 'email',
    p_perfil ->> 'username',
    coalesce(p_perfil ->> 'nombre', ''),
    coalesce(p_perfil ->> 'apellido', ''),
    p_perfil ->> 'tipo_documento',
    p_perfil ->> 'cedula',
    p_perfil ->> 'telefono',
    v_dep_uuid,
    coalesce(array(select jsonb_array_elements_text(coalesce(p_perfil -> 'roles', '[]'::jsonb))), '{}'),
    coalesce((p_perfil ->> 'is_staff')::boolean, false),
    coalesce((p_perfil ->> 'activo')::boolean, true),
    p_perfil,
    v_dep_id
  )
  on conflict (nova_user_id) do update set
    email              = excluded.email,
    username           = excluded.username,
    nombre             = excluded.nombre,
    apellido           = excluded.apellido,
    tipo_documento     = excluded.tipo_documento,
    cedula             = excluded.cedula,
    telefono           = excluded.telefono,
    nova_dependency_id = excluded.nova_dependency_id,
    nova_roles         = excluded.nova_roles,
    nova_is_staff      = excluded.nova_is_staff,
    nova_activo        = excluded.nova_activo,
    datos_nova         = excluded.datos_nova,
    -- La dependencia asignada manualmente por un ADM no se pisa.
    dependencia_id     = coalesce(u.dependencia_id, excluded.dependencia_id),
    ultimo_acceso_en   = now(),
    sincronizado_en    = now()
  returning * into v_usuario;

  return v_usuario;
end;
$$;

-- Indica si el usuario puede usar el módulo (RF-AC-005: inactivo no entra).
create or replace function fn_usuario_puede_ingresar(p_usuario_id bigint)
returns boolean
language sql stable
as $$
  select exists (
    select 1 from usuario
    where id = p_usuario_id and estado = 'activo' and nova_activo and perfil is not null
  )
$$;

-- ── Triggers comunes ─────────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array['dependencia','trd','asunto','tipo_documental','programa_academico',
                           'ubicacion_fisica','usuario','parametro','plantilla_correo']
  loop
    execute format('create trigger %I before update on %I for each row execute function fn_tocar_actualizado()', t || '_tocar', t);
  end loop;
  foreach t in array array['dependencia','trd','asunto','tipo_documental','programa_academico',
                           'ubicacion_fisica','usuario','parametro','plantilla_correo']
  loop
    execute format('create trigger %I before delete on %I for each row execute function fn_bloquear_borrado()', t || '_sin_borrado', t);
  end loop;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000300_archivos_cargas_documentos.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  03 Archivos, lotes de carga, transferencias y documentos
--  RF-AC-007 a RF-AC-012 · RN-AC-01, 03, 05, 11, 13, 14 · D-02
-- =============================================================================

-- ── Archivo físico (D-02, RN-AC-14) ─────────────────────────────────────────
-- Los archivos se guardan localmente en carpetas; aquí solo su referencia.
-- El nombre en disco es <id>.<extension>. Nunca se guardan binarios en la BD.
create table archivo (
  id               uuid primary key default gen_random_uuid(),
  ruta_relativa    text not null unique,                    -- relativa a RAIZ_ARCHIVOS, ej. documentos/110/2024/<id>.pdf
  nombre_original  text not null,
  extension        text not null check (extension ~ '^[a-z0-9]{1,10}$'),
  mime             text not null,
  tamano_bytes     bigint not null check (tamano_bytes > 0),
  hash_sha256      char(64) not null check (hash_sha256 ~ '^[0-9a-f]{64}$'),
  paginas          integer check (paginas is null or paginas > 0),
  subido_por       bigint references usuario(id),           -- null = sistema (n8n)
  subido_en        timestamptz not null default now(),
  hash_verificado_en timestamptz                            -- verificación semanal (RNF-AC-03)
);
create index archivo_hash_idx on archivo (hash_sha256);
comment on table archivo is 'D-02/RN-AC-14. Referencia (id) a un archivo guardado en carpetas locales. Los registros apuntan a archivo_id.';

-- ── Lotes de carga (RF-AC-007) ──────────────────────────────────────────────
create table lote_carga (
  id                 bigint generated always as identity primary key,
  codigo             text not null unique,                  -- L-2026-041
  tipo               tipo_carga not null,
  destino            jsonb not null default '{}'::jsonb,    -- dependencia/año/asunto o estado/año/nivel/programa
  destino_texto      text,                                  -- "Graduados / 2023 / Pregrado / Derecho"
  estado             estado_lote not null default 'pendiente',
  total_items        integer not null default 0,
  aceptados          integer not null default 0,
  duplicados         integer not null default 0,
  errores            integer not null default 0,
  informe_archivo_id uuid references archivo(id),           -- informe descargable
  transferencia_id   bigint,                                -- FK agregada abajo
  creado_por         bigint references usuario(id),
  creado_en          timestamptz not null default now(),
  iniciado_en        timestamptz,
  finalizado_en      timestamptz,
  anulado_motivo     text,
  anulado_por        bigint references usuario(id),
  anulado_en         timestamptz,
  actualizado_en     timestamptz not null default now(),
  constraint lote_anulacion_con_motivo check (estado <> 'anulado' or anulado_motivo is not null)
);

-- Cada archivo/fila dentro de un lote, con su resultado y motivo.
create table lote_item (
  id                bigint generated always as identity primary key,
  lote_id           bigint not null references lote_carga(id),
  nombre_origen     text not null,                          -- nombre del archivo o "fila 12"
  resultado         resultado_item not null default 'pendiente',
  motivo            text,                                   -- motivo de error o de duplicado
  archivo_id        uuid references archivo(id),
  registro_tipo     text,                                   -- 'documento' | 'historia_documento' | 'comunicacion' | 'inventario_item'
  registro_id       bigint,
  intentos          smallint not null default 0,
  procesado_en      timestamptz,
  constraint lote_item_error_con_motivo check (resultado not in ('error', 'duplicado') or motivo is not null)
);
create index lote_item_lote_idx on lote_item (lote_id, resultado);

-- Recalcula los contadores del lote a partir de sus ítems.
create or replace function fn_recalcular_lote(p_lote_id bigint)
returns void
language sql
as $$
  update lote_carga l set
    total_items = s.total,
    aceptados   = s.aceptados,
    duplicados  = s.duplicados,
    errores     = s.errores
  from (
    select count(*)                                       as total,
           count(*) filter (where resultado = 'aceptado')  as aceptados,
           count(*) filter (where resultado = 'duplicado') as duplicados,
           count(*) filter (where resultado = 'error')     as errores
    from lote_item where lote_id = p_lote_id
  ) s
  where l.id = p_lote_id
$$;

create or replace function fn_trg_lote_item_recalcular()
returns trigger
language plpgsql
as $$
begin
  perform fn_recalcular_lote(new.lote_id);
  return null;
end;
$$;

create trigger lote_item_recalcular
after insert or update of resultado on lote_item
for each row execute function fn_trg_lote_item_recalcular();

-- ── Transferencias documentales (RF-AC-009, RF-AC-010) ──────────────────────
create table transferencia (
  id                   bigint generated always as identity primary key,
  codigo               text not null unique,                -- TR-2026-001
  dependencia_id       bigint not null references dependencia(id),
  anio                 smallint not null check (anio between 1900 and 2100),   -- año de los documentos
  tipo                 tipo_transferencia not null,
  estado               estado_transferencia not null default 'en_proceso',
  funcionario_entrega  text not null,
  descripcion          text,
  acta_archivo_id      uuid references archivo(id),         -- acta o FUID (Excel o PDF)
  fuid_archivo_id      uuid references archivo(id),
  unidades             integer,                             -- cajas (física) o archivos (digital)
  registrado_por       bigint references usuario(id),
  registrado_en        timestamptz not null default now(),
  recibido_por         bigint references usuario(id),
  recibido_en          timestamptz,
  anulado_motivo       text,
  anulado_por          bigint references usuario(id),
  anulado_en           timestamptz,
  actualizado_en       timestamptz not null default now(),
  constraint transferencia_recibida_datos check (estado <> 'recibida' or (recibido_en is not null)),
  constraint transferencia_anulacion_con_motivo check (estado <> 'anulada' or anulado_motivo is not null)
);
create index transferencia_dep_anio_idx on transferencia (dependencia_id, anio);

alter table lote_carga
  add constraint lote_carga_transferencia_fk foreign key (transferencia_id) references transferencia(id);

-- RN-AC-03: solo se confirma (recibida) si anio <= año actual − años mínimos.
create or replace function fn_trg_transferencia_regla_anios()
returns trigger
language plpgsql
as $$
declare
  v_minimos integer := coalesce(fn_parametro_entero('anios_minimos_transferencia'), 2);
  v_maximo  integer := extract(year from current_date)::integer - v_minimos;
begin
  if new.estado = 'recibida' and (tg_op = 'INSERT' or old.estado is distinct from 'recibida') then
    if new.anio > v_maximo then
      raise exception 'RN-AC-03: en % solo se pueden transferir documentos hasta %; la transferencia es de %.',
        extract(year from current_date)::integer, v_maximo, new.anio
        using errcode = 'P0001';
    end if;
    new.recibido_en := coalesce(new.recibido_en, now());
    new.recibido_por := coalesce(new.recibido_por, fn_usuario_actual());
  end if;
  return new;
end;
$$;

create trigger transferencia_regla_anios
before insert or update of estado on transferencia
for each row execute function fn_trg_transferencia_regla_anios();

-- Inventario FUID por caja (RF-AC-009). Lo elabora la dependencia (RN-AC-04).
create table inventario_item (
  id                  bigint generated always as identity primary key,
  transferencia_id    bigint not null references transferencia(id),
  fila_origen         integer,                              -- fila del Excel
  caja                text not null,
  carpeta_tomo        text,
  asunto_id           bigint references asunto(id),
  asunto_texto        text,                                 -- como viene en el FUID
  fecha_inicial       date,
  fecha_final         date,
  folios              integer check (folios is null or folios >= 0),
  consecutivo_desde   text,
  consecutivo_hasta   text,
  ubicacion_id        bigint references ubicacion_fisica(id),
  observaciones       text,
  verificado          boolean not null default false,       -- caja verificada contra el inventario
  constraint inventario_fechas check (fecha_final is null or fecha_inicial is null or fecha_final >= fecha_inicial)
);
create index inventario_transferencia_idx on inventario_item (transferencia_id, caja);

-- ── Documentos (RF-AC-008, RF-AC-011, RF-AC-013) ────────────────────────────
create table documento (
  id                 bigint generated always as identity primary key,
  archivo_id         uuid not null references archivo(id),
  hash_sha256        char(64) not null,                     -- copia de archivo.hash_sha256 para RN-AC-11
  titulo             text,
  dependencia_id     bigint not null references dependencia(id),
  anio               smallint not null check (anio between 1900 and 2100),
  asunto_id          bigint references asunto(id),          -- RN-AC-01: un solo asunto
  tipo_documental_id bigint references tipo_documental(id),
  tipo_comunicacion  tipo_comunicacion,                     -- entrada / salida / interno (filtro de búsqueda)
  consecutivo        text,                                  -- ej. '385'
  fecha_documento    date,
  remitente          text,                                  -- persona o entidad (búsqueda por persona)
  destinatario       text,
  caja               text,
  carpeta            text,
  ubicacion_id       bigint references ubicacion_fisica(id),
  observaciones      text,
  estado             estado_documento not null default 'por_clasificar',
  origen             tipo_carga not null,
  lote_id            bigint references lote_carga(id),
  transferencia_id   bigint references transferencia(id),
  cargado_por        bigint references usuario(id),
  cargado_en         timestamptz not null default now(),
  clasificado_por    bigint references usuario(id),
  clasificado_en     timestamptz,
  anulado_motivo     text,
  anulado_por        bigint references usuario(id),
  anulado_en         timestamptz,
  actualizado_en     timestamptz not null default now(),
  constraint documento_clasificado_completo check (
    estado <> 'clasificado'
    or (asunto_id is not null and fecha_documento is not null)   -- mínimo para clasificar (supuesto, validar con el cliente)
  ),
  constraint documento_anulacion_con_motivo check (estado <> 'anulado' or anulado_motivo is not null)
);
-- RN-AC-11 (P-10, supuesto): expediente = dependencia + año + asunto. Mismo hash
-- en el mismo expediente = duplicado. Los anulados no cuentan.
create unique index documento_sin_duplicados
  on documento (dependencia_id, anio, coalesce(asunto_id, 0), hash_sha256)
  where estado <> 'anulado';
create index documento_arbol_idx on documento (dependencia_id, anio, asunto_id) where estado = 'clasificado';
create index documento_por_clasificar_idx on documento (dependencia_id, anio) where estado = 'por_clasificar';
create index documento_fecha_idx on documento (fecha_documento);
create index documento_consecutivo_idx on documento (consecutivo);
create index documento_titulo_trgm on documento using gin (titulo gin_trgm_ops);
create index documento_remitente_trgm on documento using gin (remitente gin_trgm_ops);

-- Copia el hash del archivo, valida coherencia asunto/dependencia, decide el
-- estado (clasificado / por clasificar) y registra quién clasificó.
create or replace function fn_trg_documento_preparar()
returns trigger
language plpgsql
as $$
declare
  v_dep_asunto bigint;
begin
  select hash_sha256 into new.hash_sha256 from archivo where id = new.archivo_id;

  if new.asunto_id is not null then
    select dependencia_id into v_dep_asunto from asunto where id = new.asunto_id;
    if v_dep_asunto <> new.dependencia_id then
      raise exception 'RN-AC-02: el asunto % no pertenece a la dependencia %', new.asunto_id, new.dependencia_id
        using errcode = 'P0001';
    end if;
  end if;

  if new.estado <> 'anulado' then
    if new.asunto_id is not null and new.fecha_documento is not null then
      new.estado := 'clasificado';
    else
      new.estado := 'por_clasificar';
    end if;
  end if;

  if new.estado = 'clasificado' and (tg_op = 'INSERT' or old.estado <> 'clasificado'
       or old.asunto_id is distinct from new.asunto_id) then
    new.clasificado_por := coalesce(fn_usuario_actual(), new.clasificado_por);
    new.clasificado_en  := now();
  end if;

  if new.estado = 'anulado' and (tg_op = 'INSERT' or old.estado <> 'anulado') then
    new.anulado_por := coalesce(fn_usuario_actual(), new.anulado_por);
    new.anulado_en  := now();
  end if;
  return new;
end;
$$;

create trigger documento_preparar
before insert or update on documento
for each row execute function fn_trg_documento_preparar();

-- ── Sugerencias de IA (RF-AC-012, RN-AC-13) ─────────────────────────────────
-- La IA solo sugiere; la clasificación cambia únicamente por acción humana.
-- Nunca aplica a historias académicas: por eso solo referencia documento o comunicación.
create table sugerencia_ia (
  id                    bigint generated always as identity primary key,
  documento_id          bigint references documento(id),
  comunicacion_id       bigint,                             -- FK en la migración 04
  asunto_sugerido_id    bigint references asunto(id),
  dependencia_sugerida_id bigint references dependencia(id),
  confianza             numeric(4,3) not null check (confianza between 0 and 1),
  justificacion         text,
  modelo                text,                               -- servicio/modelo usado (P-13)
  decision              decision_ia not null default 'pendiente',
  valor_final_asunto_id bigint references asunto(id),
  valor_final_dependencia_id bigint references dependencia(id),
  decidido_por          bigint references usuario(id),
  decidido_en           timestamptz,
  creado_en             timestamptz not null default now(),
  constraint sugerencia_un_objetivo check (num_nonnulls(documento_id, comunicacion_id) = 1),
  constraint sugerencia_decision_humana check (decision = 'pendiente' or decidido_por is not null)
);

-- ── Triggers comunes ─────────────────────────────────────────────────────────
create trigger lote_carga_tocar    before update on lote_carga    for each row execute function fn_tocar_actualizado();
create trigger transferencia_tocar before update on transferencia for each row execute function fn_tocar_actualizado();
create trigger documento_tocar     before update on documento     for each row execute function fn_tocar_actualizado();

do $$
declare t text;
begin
  foreach t in array array['archivo','lote_carga','lote_item','transferencia','inventario_item','documento','sugerencia_ia']
  loop
    execute format('create trigger %I before delete on %I for each row execute function fn_bloquear_borrado()', t || '_sin_borrado', t);
  end loop;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000400_comunicaciones.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  04 Comunicaciones por correo (RF-AC-015 a RF-AC-019)
--  RN-AC-08 (consecutivos), RN-AC-09 (estados), RN-AC-10 (históricos), RNF-AC-04
-- =============================================================================

-- ── Consecutivos atómicos (RN-AC-08, D-04) ──────────────────────────────────
-- Secuenciales por tipo, reinician cada año. Formato: TIPO-AAAA-NNNNNN.
-- (P-17: el mockup usa 2026-CR-01377; si el cliente lo elige, solo cambia fn_formatear_consecutivo.)
create table contador_consecutivo (
  tipo    tipo_comunicacion not null,
  anio    smallint not null,
  ultimo  integer not null default 0 check (ultimo >= 0),
  primary key (tipo, anio)
);

create or replace function fn_formatear_consecutivo(p_tipo tipo_comunicacion, p_anio integer, p_numero integer)
returns text
language sql immutable
as $$
  select format('%s-%s-%s', p_tipo, p_anio, lpad(p_numero::text, 6, '0'))
$$;

-- Toma el siguiente número de forma atómica: INSERT ... ON CONFLICT DO UPDATE
-- bloquea la fila (tipo, año), así dos transacciones concurrentes nunca
-- obtienen el mismo número. Nunca generar consecutivos en el cliente ni en n8n.
create or replace function fn_siguiente_consecutivo(p_tipo tipo_comunicacion, p_anio integer default null)
returns table (anio smallint, numero integer, consecutivo text)
language plpgsql
as $$
#variable_conflict use_column
declare
  v_anio   smallint := coalesce(p_anio, extract(year from current_date))::smallint;
  v_numero integer;
begin
  insert into contador_consecutivo as c (tipo, anio, ultimo)
  values (p_tipo, v_anio, 1)
  on conflict (tipo, anio) do update set ultimo = c.ultimo + 1
  returning c.ultimo into v_numero;

  return query select v_anio, v_numero, fn_formatear_consecutivo(p_tipo, v_anio, v_numero);
end;
$$;

-- ── Comunicaciones ──────────────────────────────────────────────────────────
create table comunicacion (
  id                     bigint generated always as identity primary key,
  tipo                   tipo_comunicacion not null,
  anio                   smallint not null,
  numero                 integer not null check (numero > 0),
  consecutivo            text not null unique,              -- ENT-2026-000001
  consecutivo_original   text,                              -- RN-AC-10: número del Excel histórico
  origen                 origen_comunicacion not null,
  estado                 estado_comunicacion not null default 'nueva',
  -- Correo
  message_id             text unique,                       -- RNF-AC-04: un correo, una comunicación
  in_reply_to            text,
  -- Remitente / destinatario
  remitente_nombre       text,
  remitente_correo       text,
  destinatario_nombre    text,
  destinatario_correo    text,
  asunto                 text not null,
  cuerpo                 text,                              -- texto plano; el HTML del correo no se renderiza sin sanitizar
  fecha_recepcion        timestamptz not null default now(),
  -- Gestión
  dependencia_id         bigint references dependencia(id), -- dependencia que debe atenderla
  fecha_limite           date,                              -- plazo de respuesta de la dependencia
  comunicacion_entrada_id bigint references comunicacion(id), -- una SAL apunta a su ENT
  estudiante_id          bigint,                            -- P-07: vínculo con historia académica (FK en 05)
  n_recordatorios        smallint not null default 0,
  ultimo_recordatorio_en date,
  por_escalar            boolean not null default false,    -- marca, no estado (I-06)
  registrado_por         bigint references usuario(id),     -- null = n8n
  cerrado_en             timestamptz,
  anulado_motivo         text,
  anulado_por            bigint references usuario(id),
  anulado_en             timestamptz,
  creado_en              timestamptz not null default now(),
  actualizado_en         timestamptz not null default now(),
  unique (tipo, anio, numero),
  constraint comunicacion_salida_enlazada check (tipo <> 'SAL' or origen = 'historico' or comunicacion_entrada_id is not null),
  constraint comunicacion_anulacion_con_motivo check (estado <> 'anulada' or anulado_motivo is not null)
);
create index comunicacion_bandeja_idx on comunicacion (estado, fecha_recepcion desc);
create index comunicacion_dependencia_idx on comunicacion (dependencia_id, estado);
create index comunicacion_vencidas_idx on comunicacion (fecha_limite) where estado in ('remitida', 'devuelta');
create index comunicacion_fecha_idx on comunicacion (anio, fecha_recepcion);
create index comunicacion_remitente_trgm on comunicacion using gin (remitente_nombre gin_trgm_ops);
create index comunicacion_asunto_trgm on comunicacion using gin (asunto gin_trgm_ops);
-- RF-AC-019: reimportar el mismo Excel no duplica (tipo + año + número original).
create unique index comunicacion_historico_unico
  on comunicacion (tipo, anio, consecutivo_original) where consecutivo_original is not null;

alter table sugerencia_ia
  add constraint sugerencia_comunicacion_fk foreign key (comunicacion_id) references comunicacion(id);

-- Historial / línea de pasos de cada comunicación.
create table comunicacion_evento (
  id               bigint generated always as identity primary key,
  comunicacion_id  bigint not null references comunicacion(id),
  tipo             tipo_evento_comunicacion not null,
  estado_anterior  estado_comunicacion,
  estado_nuevo     estado_comunicacion,
  dependencia_id   bigint references dependencia(id),
  message_id       text,                                    -- correo enviado/recibido en este evento
  detalle          jsonb not null default '{}'::jsonb,
  usuario_id       bigint references usuario(id),           -- null = sistema
  creado_en        timestamptz not null default now()
);
create index comunicacion_evento_idx on comunicacion_evento (comunicacion_id, creado_en);

-- Adjuntos de comunicaciones y de sus respuestas.
create table comunicacion_adjunto (
  id               bigint generated always as identity primary key,
  comunicacion_id  bigint not null references comunicacion(id),
  evento_id        bigint references comunicacion_evento(id), -- respuesta de dependencia, etc.
  archivo_id       uuid not null references archivo(id),
  creado_en        timestamptz not null default now(),
  unique (comunicacion_id, archivo_id)
);

-- Correos que n8n no pudo asociar (RF-AC-018).
create table correo_sin_asociar (
  id                    bigint generated always as identity primary key,
  message_id            text not null unique,
  in_reply_to           text,
  de_nombre             text,
  de_correo             text not null,
  asunto                text,
  cuerpo                text,
  recibido_en           timestamptz not null,
  motivo                text not null check (motivo in ('sin_etiqueta', 'etiqueta_no_coincide', 'remitente_externo_sin_etiqueta', 'otro')),
  posible_comunicacion_id bigint references comunicacion(id),
  adjuntos              uuid[] not null default '{}',       -- ids de archivo
  resuelto              boolean not null default false,
  resuelto_como         text check (resuelto_como in ('asociado', 'nueva')),
  comunicacion_id       bigint references comunicacion(id), -- a la que se asoció o que se creó
  resuelto_por          bigint references usuario(id),
  resuelto_en           timestamptz,
  creado_en             timestamptz not null default now(),
  constraint correo_resuelto_coherente check (not resuelto or (resuelto_como is not null and comunicacion_id is not null))
);

-- ── Máquina de estados (RN-AC-09) ───────────────────────────────────────────
create or replace function fn_transicion_valida(p_desde estado_comunicacion, p_hacia estado_comunicacion)
returns boolean
language sql immutable
as $$
  select (p_desde, p_hacia) in (
    ('nueva'::estado_comunicacion,  'remitida'::estado_comunicacion),
    ('remitida',                    'respondida_dependencia'),
    ('devuelta',                    'respondida_dependencia'),
    ('respondida_dependencia',      'devuelta'),
    ('respondida_dependencia',      'cerrada'),
    ('nueva',                       'anulada'),
    ('remitida',                    'anulada'),
    ('respondida_dependencia',      'anulada'),
    ('devuelta',                    'anulada')
  )
$$;

-- Asigna consecutivo al insertar (si no viene) y valida las transiciones en
-- cualquier UPDATE de estado, venga del backend, de n8n o de SQL directo.
create or replace function fn_trg_comunicacion_estado()
returns trigger
language plpgsql
as $$
declare
  v record;
begin
  if tg_op = 'INSERT' then
    if new.numero is null then
      select * into v from fn_siguiente_consecutivo(new.tipo, coalesce(new.anio, extract(year from new.fecha_recepcion)::integer));
      new.anio := v.anio; new.numero := v.numero; new.consecutivo := v.consecutivo;
    elsif new.consecutivo is null then
      new.consecutivo := fn_formatear_consecutivo(new.tipo, new.anio, new.numero);
    end if;
    -- Los históricos importados entran cerrados (RF-AC-019).
    if new.origen = 'historico' then
      new.estado := 'cerrada';
      new.cerrado_en := coalesce(new.cerrado_en, new.fecha_recepcion);
    elsif new.estado not in ('nueva', 'cerrada') then
      raise exception 'RN-AC-09: una comunicación nueva debe iniciar en estado "nueva" (o "cerrada" si es histórica/salida)'
        using errcode = 'P0001';
    end if;
    return new;
  end if;

  if new.estado is distinct from old.estado then
    if not fn_transicion_valida(old.estado, new.estado) then
      raise exception 'RN-AC-09: transición inválida de "%" a "%" en %', old.estado, new.estado, old.consecutivo
        using errcode = 'P0001';
    end if;
    if new.estado = 'remitida' and (new.dependencia_id is null or new.fecha_limite is null) then
      raise exception 'RF-AC-016: para remitir se requiere dependencia y plazo' using errcode = 'P0001';
    end if;
    if new.estado = 'cerrada' then
      -- Solo se cierra al enviar la respuesta al remitente: debe existir la SAL enlazada.
      if not exists (select 1 from comunicacion s where s.comunicacion_entrada_id = new.id and s.tipo = 'SAL') then
        raise exception 'RN-AC-09: solo se cierra al enviar la respuesta al remitente (falta la comunicación de salida)'
          using errcode = 'P0001';
      end if;
      new.cerrado_en := now();
    end if;
    if new.estado = 'anulada' then
      new.anulado_por := coalesce(fn_usuario_actual(), new.anulado_por);
      new.anulado_en := now();
    end if;
    if new.estado = 'remitida' then
      new.n_recordatorios := 0; new.por_escalar := false; new.ultimo_recordatorio_en := null;
    end if;

    insert into comunicacion_evento (comunicacion_id, tipo, estado_anterior, estado_nuevo, dependencia_id, usuario_id)
    values (new.id,
            case new.estado
              when 'remitida' then 'remision'
              when 'respondida_dependencia' then 'respuesta_dependencia'
              when 'devuelta' then 'devolucion'
              when 'cerrada' then 'respuesta_remitente'
              when 'anulada' then 'anulacion'
              else 'nota' end::tipo_evento_comunicacion,
            old.estado, new.estado, new.dependencia_id, fn_usuario_actual());
  end if;
  return new;
end;
$$;

create trigger comunicacion_estado
before insert or update on comunicacion
for each row execute function fn_trg_comunicacion_estado();

create trigger comunicacion_tocar before update on comunicacion for each row execute function fn_tocar_actualizado();

-- Evento de recepción al crear una comunicación.
create or replace function fn_trg_comunicacion_recepcion()
returns trigger
language plpgsql
as $$
begin
  insert into comunicacion_evento (comunicacion_id, tipo, estado_nuevo, message_id, usuario_id, detalle)
  values (new.id, 'recepcion', new.estado, new.message_id, fn_usuario_actual(),
          jsonb_build_object('origen', new.origen, 'consecutivo', new.consecutivo));
  return null;
end;
$$;

create trigger comunicacion_recepcion
after insert on comunicacion
for each row execute function fn_trg_comunicacion_recepcion();

-- ── Operaciones del circuito (usadas por backend y n8n) ─────────────────────

-- F1 (RF-AC-015): registra un correo entrante. Idempotente por Message-ID:
-- si ya existe, devuelve la comunicación existente sin duplicar.
create or replace function fn_registrar_correo_entrante(
  p_message_id text, p_remitente_nombre text, p_remitente_correo text,
  p_asunto text, p_cuerpo text, p_recibido_en timestamptz, p_in_reply_to text default null
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  select * into v from comunicacion where message_id = p_message_id;
  if found then
    return v;
  end if;
  insert into comunicacion (tipo, origen, message_id, in_reply_to, remitente_nombre, remitente_correo,
                            asunto, cuerpo, fecha_recepcion, anio, numero, consecutivo)
  values ('ENT', 'correo', p_message_id, p_in_reply_to, p_remitente_nombre, p_remitente_correo,
          coalesce(nullif(p_asunto, ''), '(sin asunto)'), p_cuerpo, p_recibido_en,
          extract(year from p_recibido_en)::smallint, null, null)
  returning * into v;
  return v;
end;
$$;

-- F1 rama respuesta (RF-AC-016): busca la comunicación a la que responde un
-- correo por la etiqueta [SGD <consecutivo>] del asunto o, si no, por In-Reply-To.
create or replace function fn_buscar_comunicacion_respondida(p_asunto text, p_in_reply_to text)
returns bigint
language plpgsql stable
as $$
declare
  v_consecutivo text := substring(p_asunto from '\[SGD ([A-Z]{3}-[0-9]{4}-[0-9]{6})\]');
  v_id bigint;
begin
  if v_consecutivo is not null then
    select id into v_id from comunicacion where consecutivo = v_consecutivo;
  end if;
  if v_id is null and p_in_reply_to is not null then
    select comunicacion_id into v_id
    from comunicacion_evento
    where message_id = p_in_reply_to and tipo in ('remision', 'devolucion')
    order by creado_en desc limit 1;
  end if;
  return v_id;
end;
$$;

-- F2 (RF-AC-016): remitir a una dependencia con plazo en días hábiles.
create or replace function fn_remitir_comunicacion(
  p_comunicacion_id bigint, p_dependencia_id bigint, p_plazo_dias_habiles integer default null,
  p_message_id_enviado text default null, p_mensaje text default null
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
  v_plazo integer := coalesce(p_plazo_dias_habiles, fn_parametro_entero('plazo_respuesta_dias_habiles'), 5);
begin
  update comunicacion
     set dependencia_id = p_dependencia_id,
         fecha_limite = fn_sumar_dias_habiles(current_date, v_plazo),
         estado = 'remitida'
   where id = p_comunicacion_id
  returning * into v;
  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id;
  end if;
  update comunicacion_evento
     set message_id = p_message_id_enviado,
         detalle = detalle || jsonb_build_object('plazo_dias_habiles', v_plazo, 'mensaje', p_mensaje)
   where id = (select max(id) from comunicacion_evento where comunicacion_id = p_comunicacion_id and tipo = 'remision');
  return v;
end;
$$;

-- F3 (RF-AC-017): crea la salida SAL enlazada y cierra la entrada, en una
-- sola transacción. Llamar solo cuando el correo se envió con éxito.
create or replace function fn_responder_remitente(
  p_entrada_id bigint, p_asunto text, p_cuerpo text, p_message_id_enviado text default null
)
returns comunicacion
language plpgsql
as $$
declare
  e comunicacion;
  s comunicacion;
begin
  select * into e from comunicacion where id = p_entrada_id for update;
  if not found or e.tipo <> 'ENT' then
    raise exception 'RF-AC-017: % no es una comunicación de entrada', p_entrada_id;
  end if;
  if e.estado <> 'respondida_dependencia' then
    raise exception 'RF-AC-017: solo se responde una comunicación "respondida_dependencia" (está en "%")', e.estado
      using errcode = 'P0001';
  end if;

  insert into comunicacion (tipo, origen, estado, message_id, destinatario_nombre, destinatario_correo,
                            asunto, cuerpo, dependencia_id, comunicacion_entrada_id, estudiante_id,
                            anio, numero, consecutivo, cerrado_en)
  values ('SAL', 'correo', 'cerrada', p_message_id_enviado, e.remitente_nombre, e.remitente_correo,
          p_asunto, p_cuerpo, e.dependencia_id, e.id, e.estudiante_id, null, null, null, now())
  returning * into s;

  update comunicacion set estado = 'cerrada' where id = e.id;
  return s;
end;
$$;

-- F4 (RF-AC-018): comunicaciones a recordar hoy. Regla: vencidas, no
-- recordadas en los últimos N días hábiles. Una fila por comunicación;
-- n8n agrupa por dependencia y envía un solo correo a cada una.
create or replace function fn_comunicaciones_a_recordar(p_hoy date default current_date)
returns table (comunicacion_id bigint, consecutivo text, dependencia_id bigint, asunto text,
               fecha_limite date, n_recordatorios smallint, dias_vencida integer)
language sql stable
as $$
  select c.id, c.consecutivo, c.dependencia_id, c.asunto, c.fecha_limite, c.n_recordatorios,
         fn_dias_habiles_entre(c.fecha_limite, p_hoy)
  from comunicacion c
  where c.estado in ('remitida', 'devuelta')
    and c.fecha_limite < p_hoy
    and fn_es_dia_habil(p_hoy)
    and (c.ultimo_recordatorio_en is null
         or fn_dias_habiles_entre(c.ultimo_recordatorio_en, p_hoy) >= coalesce(fn_parametro_entero('recordatorio_cada_dias_habiles'), 2))
  order by c.dependencia_id, c.fecha_limite
$$;

-- Registra que se envió un recordatorio y marca para escalar tras el máximo.
create or replace function fn_registrar_recordatorio(p_comunicacion_id bigint, p_message_id text default null)
returns void
language plpgsql
as $$
declare
  v_max integer := coalesce(fn_parametro_entero('max_recordatorios_antes_escalar'), 3);
  v_n   smallint;
begin
  update comunicacion
     set n_recordatorios = n_recordatorios + 1,
         ultimo_recordatorio_en = current_date,
         por_escalar = (n_recordatorios + 1) >= v_max
   where id = p_comunicacion_id
  returning n_recordatorios into v_n;

  insert into comunicacion_evento (comunicacion_id, tipo, message_id, usuario_id, detalle)
  values (p_comunicacion_id, (case when v_n >= v_max then 'marcada_escalar' else 'recordatorio' end)::tipo_evento_comunicacion,
          p_message_id, fn_usuario_actual(), jsonb_build_object('numero_recordatorio', v_n));
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['contador_consecutivo','comunicacion','comunicacion_evento','comunicacion_adjunto','correo_sin_asociar']
  loop
    execute format('create trigger %I before delete on %I for each row execute function fn_bloquear_borrado()', t || '_sin_borrado', t);
  end loop;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000500_historias_academicas.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  05 Historias académicas (RF-AC-020, RF-AC-021) · RN-AC-06, RN-AC-07, RN-AC-13
-- =============================================================================

create table estudiante (
  id                bigint generated always as identity primary key,
  tipo_documento    text not null default 'CC',
  numero_documento  text not null,
  codigo            text unique,                            -- código institucional, ej. UAC-2015-1504
  apellidos         text not null,
  nombres           text not null,
  correo            text,
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  unique (tipo_documento, numero_documento)
);
-- Orden alfabético del árbol (RN-AC-07) y búsqueda por nombre.
create index estudiante_orden_idx on estudiante (apellidos, nombres);
create index estudiante_nombre_trgm on estudiante using gin ((apellidos || ' ' || nombres) gin_trgm_ops);

-- Una historia por estudiante y programa.
create table historia_academica (
  id                bigint generated always as identity primary key,
  estudiante_id     bigint not null references estudiante(id),
  programa_id       bigint not null references programa_academico(id),
  estado            estado_historia not null default 'activa',
  anio              smallint check (anio between 1950 and 2100),   -- año de grado o retiro (nivel "Año" del árbol)
  -- RN-AC-06: activa = Registro Académico; retirado/graduado = Archivo Central.
  custodia          text generated always as (case when estado = 'activa' then 'registro_academico' else 'archivo_central' end) stored,
  observaciones     text,
  estado_cambiado_en timestamptz,
  estado_cambiado_por bigint references usuario(id),
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  unique (estudiante_id, programa_id),
  constraint historia_anio_si_inactiva check (estado = 'activa' or anio is not null)
);
create index historia_arbol_idx on historia_academica (estado, anio, programa_id);

-- Documentos de la historia. Sin IA (RN-AC-13): no existe vínculo con sugerencia_ia.
create table historia_documento (
  id                 bigint generated always as identity primary key,
  historia_id        bigint not null references historia_academica(id),
  archivo_id         uuid not null references archivo(id),
  hash_sha256        char(64) not null,                     -- copia de archivo.hash_sha256 (RN-AC-11)
  tipo_documental_id bigint references tipo_documental(id),
  descripcion        text,
  fecha_documento    date,
  lote_id            bigint references lote_carga(id),
  anulado            boolean not null default false,
  anulado_motivo     text,
  anulado_por        bigint references usuario(id),
  anulado_en         timestamptz,
  cargado_por        bigint references usuario(id),
  cargado_en         timestamptz not null default now(),
  constraint historia_doc_anulacion_con_motivo check (not anulado or anulado_motivo is not null)
);
-- RN-AC-11: en historias, el expediente es la historia del estudiante.
create unique index historia_documento_sin_duplicados
  on historia_documento (historia_id, hash_sha256) where not anulado;

create or replace function fn_trg_historia_documento_hash()
returns trigger
language plpgsql
as $$
begin
  select hash_sha256 into new.hash_sha256 from archivo where id = new.archivo_id;
  if new.anulado and (tg_op = 'INSERT' or not old.anulado) then
    new.anulado_por := coalesce(fn_usuario_actual(), new.anulado_por);
    new.anulado_en := now();
  end if;
  return new;
end;
$$;

create trigger historia_documento_hash
before insert or update on historia_documento
for each row execute function fn_trg_historia_documento_hash();

-- Registra quién y cuándo cambió el estado (graduado / retirado).
create or replace function fn_trg_historia_estado()
returns trigger
language plpgsql
as $$
begin
  if new.estado is distinct from old.estado then
    new.estado_cambiado_en := now();
    new.estado_cambiado_por := fn_usuario_actual();
  end if;
  return new;
end;
$$;

create trigger historia_estado before update of estado on historia_academica
for each row execute function fn_trg_historia_estado();

create trigger estudiante_tocar before update on estudiante for each row execute function fn_tocar_actualizado();
create trigger historia_tocar   before update on historia_academica for each row execute function fn_tocar_actualizado();

-- P-07: vínculo opcional comunicación ↔ estudiante.
alter table comunicacion
  add constraint comunicacion_estudiante_fk foreign key (estudiante_id) references estudiante(id);

do $$
declare t text;
begin
  foreach t in array array['estudiante','historia_academica','historia_documento']
  loop
    execute format('create trigger %I before delete on %I for each row execute function fn_bloquear_borrado()', t || '_sin_borrado', t);
  end loop;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000600_auditoria_seguridad_vistas.sql
-- ═════════════════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000700_backend_helpers.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  07 Helpers para el backend Next.js (setear usuario actual en transacción)
-- =============================================================================

-- Permite al backend ejecutar set_config('app.usuario_id', ...) vía RPC.
create or replace function fn_set_usuario_actual(p_usuario_id bigint)
returns void
language sql
as $$
  select set_config('app.usuario_id', coalesce(p_usuario_id::text, ''), true);
$$;

-- Wrapper transaccional para remitir comunicación con usuario.
create or replace function fn_remitir_comunicacion_usuario(
  p_usuario_id bigint,
  p_comunicacion_id bigint,
  p_dependencia_id bigint,
  p_plazo_dias_habiles integer default null,
  p_message_id_enviado text default null,
  p_mensaje text default null
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  select * into v from fn_remitir_comunicacion(p_comunicacion_id, p_dependencia_id, p_plazo_dias_habiles, p_message_id_enviado, p_mensaje);
  return v;
end;
$$;

-- Wrapper transaccional para responder al remitente.
create or replace function fn_responder_remitente_usuario(
  p_usuario_id bigint,
  p_entrada_id bigint,
  p_asunto text,
  p_cuerpo text,
  p_message_id_enviado text default null
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  select * into v from fn_responder_remitente(p_entrada_id, p_asunto, p_cuerpo, p_message_id_enviado);
  return v;
end;
$$;

-- Wrapper transaccional para devolver una respuesta incompleta.
create or replace function fn_devolver_respuesta_usuario(
  p_usuario_id bigint,
  p_comunicacion_id bigint,
  p_mensaje text default null,
  p_message_id_enviado text default null
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario_id);

  update comunicacion
     set estado = 'devuelta'
   where id = p_comunicacion_id
   returning * into v;

  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id;
  end if;

  update comunicacion_evento
     set message_id = p_message_id_enviado,
         detalle = detalle || jsonb_build_object('mensaje', p_mensaje)
   where id = (select max(id) from comunicacion_evento where comunicacion_id = p_comunicacion_id and tipo = 'devolucion');

  return v;
end;
$$;

-- Wrapper transaccional para anular una comunicación.
create or replace function fn_anular_comunicacion_usuario(
  p_usuario_id bigint,
  p_comunicacion_id bigint,
  p_motivo text
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario_id);

  update comunicacion
     set estado = 'anulada',
         anulado_motivo = p_motivo
   where id = p_comunicacion_id
   returning * into v;

  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id;
  end if;

  return v;
end;
$$;

-- Wrapper transaccional para registrar correo entrante (usado si el backend lo crea manualmente).
create or replace function fn_registrar_correo_entrante_usuario(
  p_usuario_id bigint,
  p_message_id text,
  p_remitente_nombre text,
  p_remitente_correo text,
  p_asunto text,
  p_cuerpo text,
  p_recibido_en timestamptz,
  p_in_reply_to text default null
)
returns comunicacion
language plpgsql
as $$
declare
  v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  select * into v from fn_registrar_correo_entrante(p_message_id, p_remitente_nombre, p_remitente_correo, p_asunto, p_cuerpo, p_recibido_en, p_in_reply_to);
  return v;
end;
$$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000800_n8n_registrar_comunicacion.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  08 Registro de comunicaciones entrantes desde n8n (F1 · RF-AC-015)
--  Usado por POST /api/n8n/comunicaciones del backend.
-- =============================================================================

-- Registra un correo entrante con sus adjuntos en UNA transacción.
-- Idempotente por Message-ID (RNF-AC-04): si el correo ya existe devuelve la
-- comunicación existente (creada = false) y solo agrega los adjuntos que falten,
-- así un reintento de n8n nunca duplica nada.
-- Los adjuntos son ids de la tabla `archivo` (subidos antes con POST /api/archivos).
create or replace function fn_registrar_comunicacion_n8n(
  p_message_id       text,
  p_remitente_nombre text,
  p_remitente_correo text,
  p_asunto           text,
  p_cuerpo           text,
  p_recibido_en      timestamptz,
  p_in_reply_to      text default null,
  p_adjuntos         uuid[] default '{}'
)
returns table (comunicacion_id bigint, consecutivo text, estado estado_comunicacion, creada boolean, adjuntos integer)
language plpgsql
as $$
#variable_conflict use_column
declare
  v_existia boolean;
  v comunicacion;
  v_faltantes uuid[];
begin
  if coalesce(trim(p_message_id), '') = '' then
    raise exception 'message_id es obligatorio' using errcode = '22023';
  end if;

  -- Los adjuntos deben existir en `archivo` (los registra el backend al subirlos).
  select array_agg(a) into v_faltantes
  from unnest(coalesce(p_adjuntos, '{}')) a
  where not exists (select 1 from archivo where id = a);
  if v_faltantes is not null then
    raise exception 'Adjuntos inexistentes: %', array_to_string(v_faltantes, ', ') using errcode = '23503';
  end if;

  select exists (select 1 from comunicacion where message_id = p_message_id) into v_existia;

  v := fn_registrar_correo_entrante(p_message_id, p_remitente_nombre, p_remitente_correo,
                                    p_asunto, p_cuerpo, coalesce(p_recibido_en, now()), p_in_reply_to);

  insert into comunicacion_adjunto (comunicacion_id, archivo_id)
  select v.id, a from unnest(coalesce(p_adjuntos, '{}')) a
  on conflict (comunicacion_id, archivo_id) do nothing;

  return query
  select v.id, v.consecutivo, v.estado, not v_existia,
         (select count(*)::integer from comunicacion_adjunto ad where ad.comunicacion_id = v.id);
end;
$$;

-- Sin acceso desde la API pública. En PostgreSQL EXECUTE se concede a PUBLIC por
-- defecto (y anon/authenticated lo heredan), por eso se revoca de PUBLIC y se
-- concede solo a service_role (la credencial del backend).
revoke execute on function fn_registrar_comunicacion_n8n(text, text, text, text, text, timestamptz, text, uuid[]) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_registrar_comunicacion_n8n(text, text, text, text, text, timestamptz, text, uuid[]) to service_role';
  end if;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007000900_n8n_funciones.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  09 Funciones que usan los flujos n8n de la Bandeja de comunicaciones (F1–F6)
--  Las llama el backend (rutas /api/n8n/*) con la credencial de servicio.
--
--  Origen: n8n_funciones_supabase.sql (F1 y F6, revisadas) + funciones nuevas de
--  F2, F3, F4 y compartidas, con la forma de respuesta que esperan los flujos.
--  Cambios respecto al archivo original:
--   · n8n_registrar_correo_nuevo reutiliza fn_registrar_comunicacion_n8n (08):
--     valida adjuntos y no duplica la nota de adjuntos omitidos en un reintento.
--   · n8n_registrar_respuesta_dependencia guarda el Message-ID de la respuesta en
--     el evento, y n8n_estado_correo lo usa para marcarla como ya procesada.
--   · Permisos: se revoca de PUBLIC y se concede a service_role solo si existe.
-- =============================================================================

-- ───────────── F1 · Consultar estado del correo ─────────────
create or replace function n8n_estado_correo(
  p_message_id text, p_asunto text, p_in_reply_to text, p_de_correo text)
returns table(ya_procesado boolean, comunicacion_id bigint, dependencia_id bigint,
              dependencia_nombre text, es_propio boolean)
language sql stable as $$
  select
    (exists (select 1 from comunicacion where message_id = p_message_id)
     or exists (select 1 from correo_sin_asociar where message_id = p_message_id)
     or exists (select 1 from comunicacion_evento where message_id = p_message_id and tipo = 'respuesta_dependencia')),
    fn_buscar_comunicacion_respondida(p_asunto, p_in_reply_to)::bigint,
    (select d.id from dependencia d where lower(d.correo_oficial) = lower(p_de_correo) and d.estado = 'activo' limit 1)::bigint,
    (select d.nombre from dependencia d where lower(d.correo_oficial) = lower(p_de_correo) and d.estado = 'activo' limit 1)::text,
    (lower(coalesce(p_de_correo, '')) = lower(coalesce(
       (select trim(both '"' from valor) from parametro where clave = 'buzon_archivo_central'), '')));
$$;

-- ───────────── F1 · Registrar rebote ─────────────
create or replace function n8n_registrar_rebote(p_ids text[], p_de text, p_asunto text)
returns table(asociados bigint, auditado boolean)
language plpgsql as $$
declare v_n bigint;
begin
  with ref as (
    select distinct e.comunicacion_id from comunicacion_evento e where e.message_id = any(coalesce(p_ids, '{}'))
  ), ins as (
    insert into comunicacion_evento (comunicacion_id, tipo, detalle)
    select ref.comunicacion_id, 'error_envio',
           jsonb_build_object('motivo', 'rebote', 'de', p_de, 'asunto', p_asunto)
    from ref
    returning comunicacion_id
  )
  select count(*) into v_n from ins;

  perform fn_auditar('error_flujo', 'n8n', 'F1 Correo entrante',
                     jsonb_build_object('motivo', 'rebote', 'de', p_de, 'asunto', p_asunto, 'citados', p_ids),
                     'error');
  return query select v_n, true;
end $$;

-- ───────────── F1 · A · Registrar respuesta de la dependencia ─────────────
-- Si la transición no es válida la base lanza RN-AC-09 y el flujo manda el correo a "sin asociar".
create or replace function n8n_registrar_respuesta_dependencia(
  p_comunicacion_id bigint, p_de_correo text, p_asunto text, p_cuerpo text,
  p_message_id text, p_recibido_en text, p_archivo_ids uuid[], p_adjuntos_omitidos jsonb)
returns table(id bigint, consecutivo text, estado text)
language plpgsql as $$
#variable_conflict use_column
declare
  v_evento bigint;
begin
  update comunicacion set estado = 'respondida_dependencia' where comunicacion.id = p_comunicacion_id;
  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id using errcode = '23503';
  end if;

  select max(e.id) into v_evento from comunicacion_evento e
   where e.comunicacion_id = p_comunicacion_id and e.tipo = 'respuesta_dependencia';

  update comunicacion_evento
     set message_id = p_message_id,
         detalle = coalesce(detalle, '{}'::jsonb) || jsonb_build_object(
           'de_correo', p_de_correo, 'asunto', p_asunto, 'cuerpo', p_cuerpo,
           'message_id_correo', p_message_id, 'recibido_en', p_recibido_en)
   where comunicacion_evento.id = v_evento;

  insert into comunicacion_adjunto (comunicacion_id, evento_id, archivo_id)
  select p_comunicacion_id, v_evento, a from unnest(coalesce(p_archivo_ids, '{}')) as a
  on conflict do nothing;

  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  select p_comunicacion_id, 'nota',
         jsonb_build_object('motivo', 'adjuntos_no_guardados', 'adjuntos', p_adjuntos_omitidos)
  where coalesce(p_adjuntos_omitidos, '[]'::jsonb) <> '[]'::jsonb;

  return query select c.id, c.consecutivo, c.estado::text from comunicacion c where c.id = p_comunicacion_id;
end $$;

-- ───────────── F1 · B · Registrar correo nuevo ─────────────
create or replace function n8n_registrar_correo_nuevo(
  p_message_id text, p_de_nombre text, p_de_correo text, p_asunto text, p_cuerpo text,
  p_recibido_en timestamptz, p_in_reply_to text, p_archivo_ids uuid[], p_adjuntos_omitidos jsonb)
returns table(id bigint, consecutivo text)
language plpgsql as $$
declare r record;
begin
  select * into r from fn_registrar_comunicacion_n8n(p_message_id, p_de_nombre, p_de_correo, p_asunto, p_cuerpo,
                                                     p_recibido_en, p_in_reply_to, coalesce(p_archivo_ids, '{}'));
  if r.creada and coalesce(p_adjuntos_omitidos, '[]'::jsonb) <> '[]'::jsonb then
    insert into comunicacion_evento (comunicacion_id, tipo, detalle)
    values (r.comunicacion_id, 'nota', jsonb_build_object('motivo', 'adjuntos_no_guardados', 'adjuntos', p_adjuntos_omitidos));
  end if;
  return query select r.comunicacion_id, r.consecutivo;
end $$;

-- ───────────── F1 · Guardar sugerencia (nota) ─────────────
create or replace function n8n_guardar_sugerencia(p_comunicacion_id bigint, p_detalle jsonb)
returns table(id bigint)
language sql as $$
  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  select p_comunicacion_id, 'nota', p_detalle
  where p_detalle is not null
  returning id::bigint;
$$;

-- ───────────── F1 · Guardar en correos sin asociar ─────────────
create or replace function n8n_guardar_sin_asociar(
  p_message_id text, p_in_reply_to text, p_de_nombre text, p_de_correo text, p_asunto text,
  p_cuerpo text, p_recibido_en timestamptz, p_motivo text, p_posible_comunicacion_id bigint,
  p_adjuntos uuid[])
returns table(insertados bigint)
language sql as $$
  with i as (
    insert into correo_sin_asociar (message_id, in_reply_to, de_nombre, de_correo, asunto, cuerpo,
                                    recibido_en, motivo, posible_comunicacion_id, adjuntos)
    values (p_message_id, p_in_reply_to, p_de_nombre, p_de_correo, p_asunto, p_cuerpo,
            coalesce(p_recibido_en, now()), p_motivo, p_posible_comunicacion_id, coalesce(p_adjuntos, '{}'))
    on conflict (message_id) do nothing
    returning id
  )
  select count(*) from i;
$$;

-- ───────────── F1 · Registrar error del acuse ─────────────
create or replace function n8n_registrar_error_acuse(p_comunicacion_id bigint, p_error text)
returns table(id bigint)
language sql as $$
  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  values (p_comunicacion_id, 'error_envio',
          jsonb_build_object('flujo', 'F1', 'destino', 'acuse_recibo', 'error', p_error))
  returning id::bigint;
$$;

-- ───────────── F2 · Leer comunicación y dependencia ─────────────
-- Si no existe la comunicación: {"id": null}. dep_* = dependencia indicada o, si es null, la de la comunicación.
create or replace function n8n_leer_remision(p_comunicacion_id bigint, p_dependencia_id bigint default null)
returns jsonb
language sql stable as $$
  select coalesce((
    select jsonb_build_object(
      'id', c.id, 'tipo', c.tipo, 'estado', c.estado, 'consecutivo', c.consecutivo, 'asunto', c.asunto,
      'dep_id', d.id, 'dependencia', d.nombre, 'dep_estado', d.estado, 'correo_oficial', d.correo_oficial,
      'plazo_defecto', fn_parametro_entero('plazo_respuesta_dias_habiles'),
      'adjuntos', coalesce((select jsonb_agg(ad.archivo_id order by ad.id) from comunicacion_adjunto ad where ad.comunicacion_id = c.id), '[]'::jsonb))
    from comunicacion c
    left join dependencia d on d.id = coalesce(p_dependencia_id, c.dependencia_id)
    where c.id = p_comunicacion_id
  ), jsonb_build_object('id', null));
$$;

-- ───────────── F2 · Registrar remisión (tras enviar el correo) ─────────────
create or replace function n8n_remitir(
  p_usuario bigint, p_comunicacion_id bigint, p_dependencia_id bigint,
  p_plazo integer, p_message_id text, p_mensaje text)
returns jsonb
language plpgsql as $$
declare v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario);
  v := fn_remitir_comunicacion(p_comunicacion_id, p_dependencia_id, p_plazo, p_message_id, p_mensaje);
  return jsonb_build_object('id', v.id, 'consecutivo', v.consecutivo, 'estado', v.estado,
                            'dependencia_id', v.dependencia_id, 'fecha_limite', v.fecha_limite);
end $$;

-- ───────────── F2 · Registrar devolución (tras enviar el correo) ─────────────
-- Da un nuevo plazo (parámetro plazo_respuesta_dias_habiles) para que los recordatorios cuenten desde hoy.
create or replace function n8n_devolver(
  p_usuario bigint, p_comunicacion_id bigint, p_message_id text, p_dependencia_id bigint, p_mensaje text)
returns jsonb
language plpgsql as $$
declare v comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario);
  if p_dependencia_id is not null
     and not exists (select 1 from comunicacion where id = p_comunicacion_id and dependencia_id = p_dependencia_id) then
    raise exception 'La comunicación % no está remitida a la dependencia %', p_comunicacion_id, p_dependencia_id using errcode = '22023';
  end if;
  v := fn_devolver_respuesta_usuario(p_usuario, p_comunicacion_id, p_mensaje, p_message_id);
  update comunicacion
     set fecha_limite = fn_sumar_dias_habiles(current_date, coalesce(fn_parametro_entero('plazo_respuesta_dias_habiles'), 5)),
         n_recordatorios = 0, por_escalar = false, ultimo_recordatorio_en = null
   where id = v.id
  returning * into v;
  return jsonb_build_object('id', v.id, 'consecutivo', v.consecutivo, 'estado', v.estado,
                            'dependencia_id', v.dependencia_id, 'fecha_limite', v.fecha_limite);
end $$;

-- ───────────── F3 · Leer comunicación de entrada ─────────────
-- adjuntos: [{archivo_id, de_dependencia}] — de_dependencia = vino en la respuesta de la dependencia.
create or replace function n8n_leer_entrada(p_comunicacion_id bigint)
returns jsonb
language sql stable as $$
  select coalesce((
    select jsonb_build_object(
      'id', c.id, 'tipo', c.tipo, 'estado', c.estado, 'consecutivo', c.consecutivo, 'asunto', c.asunto,
      'remitente_nombre', c.remitente_nombre, 'remitente_correo', c.remitente_correo,
      'adjuntos', coalesce((
        select jsonb_agg(jsonb_build_object('archivo_id', ad.archivo_id,
                                            'de_dependencia', coalesce(ev.tipo = 'respuesta_dependencia', false))
                         order by ad.id)
        from comunicacion_adjunto ad
        left join comunicacion_evento ev on ev.id = ad.evento_id
        where ad.comunicacion_id = c.id), '[]'::jsonb))
    from comunicacion c where c.id = p_comunicacion_id
  ), jsonb_build_object('id', null));
$$;

-- ───────────── F3 · Registrar salida y cerrar la entrada (tras enviar el correo) ─────────────
create or replace function n8n_responder(
  p_usuario bigint, p_entrada_id bigint, p_asunto text, p_cuerpo text, p_message_id text, p_archivos uuid[])
returns jsonb
language plpgsql as $$
declare
  s comunicacion;
  v_ajenos uuid[];
begin
  select array_agg(a) into v_ajenos
  from unnest(coalesce(p_archivos, '{}')) a
  where not exists (select 1 from comunicacion_adjunto ad where ad.comunicacion_id = p_entrada_id and ad.archivo_id = a);
  if v_ajenos is not null then
    raise exception 'Archivos que no son adjuntos de la comunicación %: %', p_entrada_id, array_to_string(v_ajenos, ', ')
      using errcode = '22023';
  end if;

  s := fn_responder_remitente_usuario(p_usuario, p_entrada_id, p_asunto, p_cuerpo, p_message_id);

  insert into comunicacion_adjunto (comunicacion_id, archivo_id)
  select s.id, a from unnest(coalesce(p_archivos, '{}')) a
  on conflict do nothing;

  return jsonb_build_object('id', s.id, 'consecutivo', s.consecutivo, 'estado', s.estado,
                            'entrada_id', p_entrada_id, 'adjuntos', coalesce(array_length(p_archivos, 1), 0));
end $$;

-- ───────────── Compartida F2/F3/F4 · Error de envío ─────────────
create or replace function n8n_registrar_error_envio(
  p_usuario bigint, p_comunicaciones bigint[], p_dependencia bigint, p_detalle jsonb)
returns jsonb
language plpgsql as $$
declare v_n integer;
begin
  perform fn_set_usuario_actual(p_usuario);
  with ins as (
    insert into comunicacion_evento (comunicacion_id, tipo, dependencia_id, usuario_id, detalle)
    select c.id, 'error_envio', p_dependencia, p_usuario, coalesce(p_detalle, '{}'::jsonb)
    from comunicacion c where c.id = any(coalesce(p_comunicaciones, '{}'))
    returning 1
  )
  select count(*) into v_n from ins;

  perform fn_auditar('error_envio', 'n8n', coalesce(p_detalle ->> 'flujo', 'n8n'),
                     coalesce(p_detalle, '{}'::jsonb) || jsonb_build_object('comunicaciones', p_comunicaciones), 'error');
  return jsonb_build_object('registrados', v_n);
end $$;

-- ───────────── Compartida F2/F3 · Auditar (p. ej. enviado pero no registrado) ─────────────
create or replace function n8n_auditar(p_flujo text, p_detalle jsonb)
returns jsonb
language plpgsql as $$
begin
  perform fn_auditar('error_flujo', 'n8n', p_flujo, coalesce(p_detalle, '{}'::jsonb), 'error');
  return jsonb_build_object('ok', true);
end $$;

-- ───────────── F6 · Registrar error de un flujo en la auditoría ─────────────
create or replace function n8n_auditar_error_flujo(
  p_flujo text, p_ejecucion text, p_nodo text, p_mensaje text, p_url text)
returns boolean
language plpgsql as $$
begin
  perform fn_auditar('error_flujo', 'n8n', p_flujo,
                     jsonb_build_object('ejecucion', p_ejecucion, 'nodo', p_nodo, 'error', p_mensaje, 'url', p_url),
                     'error');
  return true;
end $$;

-- ───────────── F4 · ¿Hoy es día hábil? ─────────────
create or replace function n8n_es_dia_habil()
returns jsonb
language sql stable as $$
  select jsonb_build_object('habil', fn_es_dia_habil(current_date));
$$;

-- ───────────── F4 · Pendientes por dependencia (una fila por dependencia) ─────────────
create or replace function n8n_recordatorios_pendientes()
returns table(dependencia_id bigint, nombre text, correo_oficial text, pendientes jsonb)
language sql stable as $$
  select d.id, d.nombre, d.correo_oficial,
         jsonb_agg(jsonb_build_object('id', r.comunicacion_id, 'consecutivo', r.consecutivo, 'asunto', r.asunto,
                                      'fecha_limite', r.fecha_limite, 'dias_vencida', r.dias_vencida)
                   order by r.fecha_limite)
  from fn_comunicaciones_a_recordar() r
  join dependencia d on d.id = r.dependencia_id
  group by d.id, d.nombre, d.correo_oficial
  order by d.nombre;
$$;

-- ───────────── F4 · Registrar recordatorios enviados ─────────────
create or replace function n8n_registrar_recordatorios(p_ids bigint[], p_message_id text)
returns jsonb
language plpgsql as $$
declare
  v_id bigint;
  v_n integer := 0;
begin
  foreach v_id in array coalesce(p_ids, '{}') loop
    perform fn_registrar_recordatorio(v_id, p_message_id);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object(
    'registrados', v_n,
    'por_escalar', (select count(*) from comunicacion where id = any(coalesce(p_ids, '{}')) and por_escalar));
end $$;

-- ───────────── F4 · Resumen del día (una fila por comunicación activa) ─────────────
create or replace function n8n_resumen_dia()
returns table(buzon text, consecutivo text, estado text, vencida boolean, por_escalar boolean,
              dependencia text, dias_desde_recepcion integer)
language sql stable as $$
  select (select trim(both '"' from valor) from parametro where clave = 'buzon_archivo_central'),
         b.consecutivo, b.estado::text, b.vencida, b.por_escalar, b.dependencia, b.dias_desde_recepcion
  from v_bandeja_comunicaciones b
  where b.estado in ('nueva', 'remitida', 'respondida_dependencia', 'devuelta')
  order by b.fecha_recepcion;
$$;

-- ───────────── Permisos: solo la credencial de servicio (backend) ─────────────
do $$
declare
  f record;
  hay_service_role boolean := exists (select 1 from pg_roles where rolname = 'service_role');
begin
  for f in
    select p.oid::regprocedure as firma
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'n8n\_%'
  loop
    execute format('revoke execute on function %s from public', f.firma);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke execute on function %s from anon', f.firma);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke execute on function %s from authenticated', f.firma);
    end if;
    if hay_service_role then
      execute format('grant execute on function %s to service_role', f.firma);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007001000_plantillas_variables_n8n.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  10 Plantillas de correo alineadas con las variables que envían los flujos n8n
--  (F2 remisión/devolución, F4 recordatorio → F5 envío).
--
--  Problema: remision y devolucion no mostraban {mensaje} (lo que escribe Archivo
--  Central / lo que falta en la respuesta) y devolucion usaba {plazo}, que F2 envía
--  vacío; recordatorio usaba {respuesta} pero F4 envía la lista en {pendientes}.
--  Solo se actualizan las plantillas que siguen con el texto original (no se pisan
--  las personalizadas desde la pantalla de Plantillas).
-- =============================================================================

with nuevas(codigo, asunto, cuerpo) as (
  values
  ('remision',
   '[SGD {consecutivo}] {asunto}',
   E'Señores {dependencia}:\n\nRemitimos la comunicación {consecutivo} sobre "{asunto}" para su atención. Plazo de respuesta: {plazo}.\n\n{mensaje}\n\nResponda este correo sin modificar el asunto.\n\nArchivo Central'),
  ('devolucion',
   '[SGD {consecutivo}] Respuesta incompleta: {asunto}',
   E'Señores {dependencia}:\n\nLa respuesta a la comunicación {consecutivo} sobre "{asunto}" está incompleta:\n\n{mensaje}\n\nPor favor compleméntela respondiendo este correo sin modificar el asunto.\n\nArchivo Central'),
  ('recordatorio',
   'Comunicaciones pendientes de respuesta',
   E'Señores {dependencia}:\n\nLas siguientes comunicaciones superaron su plazo de respuesta:\n\n{pendientes}\n\nResponda cada una desde su correo original sin modificar el asunto.\n\nArchivo Central')
)
update plantilla_correo p
   set asunto = n.asunto,
       cuerpo = n.cuerpo,
       cuerpo_original = n.cuerpo
  from nuevas n
 where p.codigo = n.codigo
   and p.cuerpo = p.cuerpo_original;   -- no tocar plantillas personalizadas


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261007001100_comunicacion_gmail.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  11 Datos de Gmail en la comunicación
--  gmail_thread_id : hilo de Gmail donde se conversa el trámite (uno por comunicación).
--  ultimo_envio_id : Message-ID del último correo que envió Archivo Central
--                    (remisión, devolución, acuse o recordatorio); se sobrescribe en cada envío.
--  No son llaves foráneas: son identificadores que genera Gmail, no filas de otra tabla.
-- =============================================================================

alter table comunicacion
  add column if not exists gmail_thread_id text,
  add column if not exists ultimo_envio_id text;

comment on column comunicacion.gmail_thread_id is 'Hilo de Gmail del trámite (threadId). Permite asociar respuestas aunque borren la etiqueta del asunto.';
comment on column comunicacion.ultimo_envio_id is 'Message-ID del último correo enviado por Archivo Central. Se actualiza solo desde comunicacion_evento.';

create index if not exists comunicacion_gmail_thread_idx
  on comunicacion (gmail_thread_id) where gmail_thread_id is not null;

-- ultimo_envio_id se mantiene solo: cada vez que un evento de envío guarda su
-- message_id, se copia a la comunicación. Así nunca queda desincronizado.
create or replace function fn_trg_evento_ultimo_envio()
returns trigger
language plpgsql
as $$
begin
  if new.message_id is not null
     and new.tipo in ('acuse_recibo', 'remision', 'devolucion', 'recordatorio', 'marcada_escalar') then
    update comunicacion
       set ultimo_envio_id = new.message_id
     where id = new.comunicacion_id
       and ultimo_envio_id is distinct from new.message_id;
  end if;
  return null;
end;
$$;

drop trigger if exists comunicacion_evento_ultimo_envio on comunicacion_evento;
create trigger comunicacion_evento_ultimo_envio
after insert or update of message_id on comunicacion_evento
for each row execute function fn_trg_evento_ultimo_envio();

-- Rellena las comunicaciones que ya tienen envíos registrados.
update comunicacion c
   set ultimo_envio_id = e.message_id
  from (
    select distinct on (comunicacion_id) comunicacion_id, message_id
    from comunicacion_evento
    where message_id is not null
      and tipo in ('acuse_recibo', 'remision', 'devolucion', 'recordatorio', 'marcada_escalar')
    order by comunicacion_id, creado_en desc, id desc
  ) e
 where c.id = e.comunicacion_id;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261010000000_mejorar_feedback_errores_respuesta.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Mejora la retroalimentación de errores en F3 (responder al remitente).
-- Añade [campo:...|tipo:...] a los mensajes para que el backend pueda devolver
-- { error, detalle, campo, tipo } y n8n/localice rápidamente el problema.

create or replace function fn_responder_remitente(
  p_entrada_id bigint, p_asunto text, p_cuerpo text, p_message_id_enviado text default null
)
returns comunicacion
language plpgsql
as $$
declare
  e comunicacion;
  s comunicacion;
begin
  select * into e from comunicacion where id = p_entrada_id for update;
  if not found then
    raise exception '[campo:entrada_id|tipo:existente] RF-AC-017: la comunicación % no existe', p_entrada_id;
  end if;
  if e.tipo <> 'ENT' then
    raise exception '[campo:entrada_id|tipo:tipo] RF-AC-017: la comunicación % no es una entrada', p_entrada_id;
  end if;
  if e.estado <> 'respondida_dependencia' then
    raise exception '[campo:entrada_id|tipo:estado] RF-AC-017: solo se responde una comunicación "respondida_dependencia" (está en "%")', e.estado
      using errcode = 'P0001';
  end if;

  insert into comunicacion (tipo, origen, estado, message_id, destinatario_nombre, destinatario_correo,
                            asunto, cuerpo, dependencia_id, comunicacion_entrada_id, estudiante_id,
                            anio, numero, consecutivo, cerrado_en)
  values ('SAL', 'correo', 'cerrada', p_message_id_enviado, e.remitente_nombre, e.remitente_correo,
          p_asunto, p_cuerpo, e.dependencia_id, e.id, e.estudiante_id, null, null, null, now())
  returning * into s;

  update comunicacion set estado = 'cerrada' where id = e.id;
  return s;
end;
$$;

create or replace function n8n_responder(
  p_usuario bigint, p_entrada_id bigint, p_asunto text, p_cuerpo text, p_message_id text, p_archivos uuid[])
returns jsonb
language plpgsql as $$
declare
  s comunicacion;
  v_ajenos uuid[];
begin
  select array_agg(a) into v_ajenos
  from unnest(coalesce(p_archivos, '{}')) a
  where not exists (select 1 from comunicacion_adjunto ad where ad.comunicacion_id = p_entrada_id and ad.archivo_id = a);
  if v_ajenos is not null then
    raise exception '[campo:archivos|tipo:adjuntos] Archivos que no son adjuntos de la comunicación %: %', p_entrada_id, array_to_string(v_ajenos, ', ')
      using errcode = '22023';
  end if;

  s := fn_responder_remitente_usuario(p_usuario, p_entrada_id, p_asunto, p_cuerpo, p_message_id);

  insert into comunicacion_adjunto (comunicacion_id, archivo_id)
  select s.id, a from unnest(coalesce(p_archivos, '{}')) a
  on conflict do nothing;

  return jsonb_build_object('id', s.id, 'consecutivo', s.consecutivo, 'estado', s.estado,
                            'entrada_id', p_entrada_id, 'adjuntos', coalesce(array_length(p_archivos, 1), 0));
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261011000000_f4_manual_y_correo_adicional.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- F4 manual + correo adicional + respuesta directa sin dependencia.
-- Nota: la respuesta directa permite la transición nueva -> respondida_dependencia,
-- lo cual es una excepción documentada a RN-AC-09 para correos que no requieren dependencia.

-- Nuevo tipo de evento para correos adicionales manuales.
alter type tipo_evento_comunicacion add value 'correo_adicional';

-- Ampliar plantillas de correo para permitir el tipo 'adicional'.
alter table plantilla_correo drop constraint if exists plantilla_correo_codigo_check;
alter table plantilla_correo add constraint plantilla_correo_codigo_check
  check (codigo in ('acuse_recibo', 'remision', 'devolucion', 'respuesta', 'recordatorio', 'resumen', 'adicional'));

insert into plantilla_correo (codigo, nombre, asunto, cuerpo, cuerpo_original)
values ('adicional', 'Correo adicional', '{asunto}', '{cuerpo}', '{cuerpo}')
on conflict (codigo) do nothing;

-- Registra un correo adicional enviado manualmente como evento de la comunicación.
create or replace function n8n_registrar_correo_adicional(
  p_usuario bigint,
  p_comunicacion_id bigint,
  p_destinatario_tipo text,
  p_destinatario_correo text,
  p_asunto text,
  p_cuerpo text,
  p_archivos uuid[],
  p_message_id text default null
)
returns jsonb
language plpgsql as $$
declare
  v_evento_id bigint;
  v_existentes uuid[];
  v_ajenos uuid[];
begin
  perform fn_set_usuario_actual(p_usuario);

  -- Validar que los archivos sean adjuntos de la comunicación.
  select array_agg(a) into v_ajenos
  from unnest(coalesce(p_archivos, '{}')) a
  where not exists (select 1 from comunicacion_adjunto ad where ad.comunicacion_id = p_comunicacion_id and ad.archivo_id = a);
  if v_ajenos is not null then
    raise exception '[campo:archivos|tipo:adjuntos] Archivos que no son adjuntos de la comunicación %: %', p_comunicacion_id, array_to_string(v_ajenos, ', ')
      using errcode = '22023';
  end if;

  insert into comunicacion_evento (comunicacion_id, tipo, usuario_id, detalle, message_id)
  values (p_comunicacion_id, 'correo_adicional', p_usuario,
          jsonb_build_object(
            'destinatario_tipo', p_destinatario_tipo,
            'destinatario_correo', p_destinatario_correo,
            'asunto', p_asunto,
            'cuerpo', p_cuerpo
          ),
          p_message_id)
  returning id into v_evento_id;

  insert into comunicacion_adjunto (comunicacion_id, evento_id, archivo_id)
  select p_comunicacion_id, v_evento_id, a from unnest(coalesce(p_archivos, '{}')) a
  on conflict do nothing;

  return jsonb_build_object('evento_id', v_evento_id, 'comunicacion_id', p_comunicacion_id, 'adjuntos', coalesce(array_length(p_archivos, 1), 0));
end $$;

-- Prepara una entrada para responder directamente sin pasar por una dependencia.
-- Excepción a RN-AC-09: permite nueva -> respondida_dependencia cuando AC responde al remitente.
create or replace function fn_responder_directo(
  p_usuario_id bigint,
  p_comunicacion_id bigint,
  p_mensaje text default null
)
returns comunicacion
language plpgsql as $$
declare
  v comunicacion;
  v_estado_anterior estado_comunicacion;
begin
  perform fn_set_usuario_actual(p_usuario_id);

  select * into v from comunicacion where id = p_comunicacion_id for update;
  if not found then
    raise exception '[campo:comunicacion_id|tipo:existente] RF-AC-017: la comunicación % no existe', p_comunicacion_id;
  end if;
  if v.tipo <> 'ENT' then
    raise exception '[campo:comunicacion_id|tipo:tipo] RF-AC-017: la comunicación % no es una entrada', p_comunicacion_id;
  end if;
  if v.estado in ('cerrada', 'anulada') then
    raise exception '[campo:comunicacion_id|tipo:estado] No se puede responder una comunicación "%"', v.estado
      using errcode = 'P0001';
  end if;

  v_estado_anterior := v.estado;
  update comunicacion set estado = 'respondida_dependencia' where id = p_comunicacion_id returning * into v;

  insert into comunicacion_evento (comunicacion_id, tipo, estado_anterior, estado_nuevo, usuario_id, detalle)
  values (p_comunicacion_id, 'respuesta_dependencia', v_estado_anterior, 'respondida_dependencia', p_usuario_id,
          jsonb_build_object('directo', true, 'mensaje', p_mensaje));

  return v;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261012000000_docx_formato_permitido.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Asegura que .docx (y el resto de formatos de oficina/imagen comunes) estén en la lista blanca.
insert into parametro (clave, valor, tipo, descripcion)
values (
  'formatos_permitidos',
  'pdf,jpg,jpeg,png,doc,docx,xls,xlsx,txt,zip',
  'lista',
  'Extensiones de archivo permitidas para carga en el SGD'
)
on conflict (clave) do update set
  valor = excluded.valor,
  actualizado_en = now();


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261012000000_responder_directo_transicion.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  12 Responder directamente al remitente (sin remitir a una dependencia)
--
--  Problema: fn_responder_directo (migración 11) documenta una excepción a RN-AC-09
--  ("nueva → respondida_dependencia"), pero el trigger de estados nunca la admitió:
--  el UPDATE fallaba con «RN-AC-09: transición inválida de "nueva" a
--  "respondida_dependencia"» y la pantalla mostraba un error genérico.
--
--  Solución: la excepción vale SOLO dentro de fn_responder_directo, mediante una
--  bandera local a la transacción (app.responder_directo). Ningún otro camino
--  (backend, n8n, SQL directo) puede saltarse la regla. Además se deja un único
--  evento en el historial (antes se insertaban dos: el del trigger y el de la función).
-- =============================================================================

create or replace function fn_trg_comunicacion_estado()
returns trigger
language plpgsql
as $$
declare
  v record;
  v_excepcion_directa boolean;
begin
  if tg_op = 'INSERT' then
    if new.numero is null then
      select * into v from fn_siguiente_consecutivo(new.tipo, coalesce(new.anio, extract(year from new.fecha_recepcion)::integer));
      new.anio := v.anio; new.numero := v.numero; new.consecutivo := v.consecutivo;
    elsif new.consecutivo is null then
      new.consecutivo := fn_formatear_consecutivo(new.tipo, new.anio, new.numero);
    end if;
    -- Los históricos importados entran cerrados (RF-AC-019).
    if new.origen = 'historico' then
      new.estado := 'cerrada';
      new.cerrado_en := coalesce(new.cerrado_en, new.fecha_recepcion);
    elsif new.estado not in ('nueva', 'cerrada') then
      raise exception 'RN-AC-09: una comunicación nueva debe iniciar en estado "nueva" (o "cerrada" si es histórica/salida)'
        using errcode = 'P0001';
    end if;
    return new;
  end if;

  if new.estado is distinct from old.estado then
    -- Excepción documentada: Archivo Central responde directo al remitente sin remitir.
    -- Solo la activa fn_responder_directo, y solo para una ENT que está en "nueva".
    v_excepcion_directa := coalesce(current_setting('app.responder_directo', true), '') = 'on'
                           and old.estado = 'nueva' and new.estado = 'respondida_dependencia' and old.tipo = 'ENT';

    if not fn_transicion_valida(old.estado, new.estado) and not v_excepcion_directa then
      raise exception 'RN-AC-09: transición inválida de "%" a "%" en %', old.estado, new.estado, old.consecutivo
        using errcode = 'P0001';
    end if;
    if new.estado = 'remitida' and (new.dependencia_id is null or new.fecha_limite is null) then
      raise exception 'RF-AC-016: para remitir se requiere dependencia y plazo' using errcode = 'P0001';
    end if;
    if new.estado = 'cerrada' then
      -- Solo se cierra al enviar la respuesta al remitente: debe existir la SAL enlazada.
      if not exists (select 1 from comunicacion s where s.comunicacion_entrada_id = new.id and s.tipo = 'SAL') then
        raise exception 'RN-AC-09: solo se cierra al enviar la respuesta al remitente (falta la comunicación de salida)'
          using errcode = 'P0001';
      end if;
      new.cerrado_en := now();
    end if;
    if new.estado = 'anulada' then
      new.anulado_por := coalesce(fn_usuario_actual(), new.anulado_por);
      new.anulado_en := now();
    end if;
    if new.estado = 'remitida' then
      new.n_recordatorios := 0; new.por_escalar := false; new.ultimo_recordatorio_en := null;
    end if;

    insert into comunicacion_evento (comunicacion_id, tipo, estado_anterior, estado_nuevo, dependencia_id, usuario_id)
    values (new.id,
            case new.estado
              when 'remitida' then 'remision'
              when 'respondida_dependencia' then 'respuesta_dependencia'
              when 'devuelta' then 'devolucion'
              when 'cerrada' then 'respuesta_remitente'
              when 'anulada' then 'anulacion'
              else 'nota' end::tipo_evento_comunicacion,
            old.estado, new.estado, new.dependencia_id, fn_usuario_actual());
  end if;
  return new;
end;
$$;

-- Prepara una entrada para responder directamente al remitente (F3 la cierra después de enviar el correo).
-- Acepta ENT en cualquier estado activo: nueva, remitida, devuelta o respondida_dependencia.
create or replace function fn_responder_directo(
  p_usuario_id bigint,
  p_comunicacion_id bigint,
  p_mensaje text default null
)
returns comunicacion
language plpgsql as $$
declare
  v comunicacion;
  v_estado_anterior estado_comunicacion;
  v_evento bigint;
begin
  perform fn_set_usuario_actual(p_usuario_id);

  select * into v from comunicacion where id = p_comunicacion_id for update;
  if not found then
    raise exception '[campo:comunicacion_id|tipo:existente] RF-AC-017: la comunicación % no existe', p_comunicacion_id;
  end if;
  if v.tipo <> 'ENT' then
    raise exception '[campo:comunicacion_id|tipo:tipo] RF-AC-017: la comunicación % no es una entrada', p_comunicacion_id;
  end if;
  if v.estado in ('cerrada', 'anulada') then
    raise exception '[campo:comunicacion_id|tipo:estado] No se puede responder una comunicación "%"', v.estado
      using errcode = 'P0001';
  end if;

  v_estado_anterior := v.estado;

  if v_estado_anterior <> 'respondida_dependencia' then
    -- Bandera válida solo en esta transacción (true = local) y solo para este UPDATE.
    perform set_config('app.responder_directo', 'on', true);
    update comunicacion set estado = 'respondida_dependencia' where id = p_comunicacion_id returning * into v;
    perform set_config('app.responder_directo', '', true);

    -- El trigger ya registró el evento de cambio de estado: se marca como respuesta directa.
    select max(id) into v_evento from comunicacion_evento
     where comunicacion_id = p_comunicacion_id and tipo = 'respuesta_dependencia';
    update comunicacion_evento
       set detalle = coalesce(detalle, '{}'::jsonb) || jsonb_build_object('directo', true, 'mensaje', p_mensaje)
     where id = v_evento;
  else
    -- Ya estaba respondida: no cambia de estado, solo se deja constancia de la respuesta directa.
    insert into comunicacion_evento (comunicacion_id, tipo, usuario_id, detalle)
    values (p_comunicacion_id, 'nota', p_usuario_id,
            jsonb_build_object('directo', true, 'mensaje', p_mensaje, 'motivo', 'respuesta_directa_al_remitente'));
  end if;

  return v;
end $$;

-- Solo el backend (service_role) puede llamarla.
revoke execute on function fn_responder_directo(bigint, bigint, text) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_responder_directo(bigint, bigint, text) to service_role';
  end if;
end $$;

notify pgrst, 'reload schema';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261013000000_validar_usuario_actual.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  13 Validar el usuario que actúa (fn_set_usuario_actual)
--
--  Problema: si un flujo de n8n (o una prueba manual) manda un usuario_id que no existe
--  en la tabla `usuario`, la acción fallaba más adelante con
--  «insert or update on table "comunicacion_evento" violates foreign key constraint
--  "comunicacion_evento_usuario_id_fkey"», sin decir qué usuario ni qué campo.
--
--  Solución: todas las funciones del backend y de n8n llaman a fn_set_usuario_actual;
--  se valida ahí, una sola vez, y el error se devuelve con la etiqueta [campo:|tipo:]
--  que el backend ya traduce a un 400 claro. NULL sigue permitido (acción del sistema).
-- =============================================================================

create or replace function fn_set_usuario_actual(p_usuario_id bigint)
returns void
language plpgsql
as $$
begin
  if p_usuario_id is not null and not exists (select 1 from usuario where id = p_usuario_id) then
    raise exception '[campo:usuario|tipo:existente] El usuario % no existe en la tabla usuario: el usuario_id que envía el flujo debe ser el id del usuario de Archivo Central que realiza la acción', p_usuario_id
      using errcode = '22023';
  end if;
  perform set_config('app.usuario_id', coalesce(p_usuario_id::text, ''), true);
end;
$$;

notify pgrst, 'reload schema';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261014000000_correo_enviado.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  14 Copia de cada correo que envía el sistema (para verlo desde el historial)
--
--  Problema: de los correos que salen por F5 (remisión, recordatorio, devolución,
--  acuse, respuesta, adicional) la base solo guardaba el Message-ID; el texto final
--  (plantilla ya armada) quedaba únicamente en Gmail.
--
--  Solución: F5 —único lugar donde el sistema envía correo— registra una copia con
--  POST /api/n8n/correos/enviado → n8n_registrar_correo_enviado. Idempotente por
--  Message-ID (RN 12): si n8n reintenta, no se duplica. La copia es inmutable.
-- =============================================================================

create table if not exists correo_enviado (
  id               bigint generated always as identity primary key,
  message_id       text not null unique,                   -- Message-ID real del correo enviado
  comunicacion_id  bigint references comunicacion(id),     -- primera comunicación del asunto [SGD …]
  plantilla        text,                                   -- código de plantilla_correo usado
  para             text not null,
  asunto           text not null,
  cuerpo           text,                                   -- texto plano, tal como salió
  archivo_ids      uuid[] not null default '{}',
  enviado_en       timestamptz not null default now(),
  creado_en        timestamptz not null default now()
);
create index if not exists correo_enviado_comunicacion_idx on correo_enviado (comunicacion_id, enviado_en);

-- Sin acceso por la API pública (igual que el resto de tablas, migración 06).
alter table correo_enviado enable row level security;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on table correo_enviado from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on table correo_enviado from authenticated';
  end if;
end $$;

-- Copia inmutable: no se edita ni se borra (RN-AC: sin borrado físico, auditoría).
create or replace function fn_trg_correo_enviado_inmutable()
returns trigger language plpgsql as $$
begin
  raise exception 'correo_enviado es inmutable: no se modifica ni se elimina' using errcode = 'P0001';
end $$;

drop trigger if exists trg_correo_enviado_inmutable on correo_enviado;
create trigger trg_correo_enviado_inmutable
  before update or delete on correo_enviado
  for each row execute function fn_trg_correo_enviado_inmutable();

-- F5 registra la copia del correo que acaba de enviar.
-- comunicacion_id es opcional: si no viene, se toma del primer consecutivo del asunto.
create or replace function n8n_registrar_correo_enviado(
  p_message_id      text,
  p_para            text,
  p_asunto          text,
  p_cuerpo          text default null,
  p_plantilla       text default null,
  p_comunicacion_id bigint default null,
  p_consecutivos    text[] default '{}',
  p_archivo_ids     uuid[] default '{}',
  p_enviado_en      timestamptz default null
)
returns jsonb
language plpgsql as $$
declare
  v_id bigint;
  v_com bigint := p_comunicacion_id;
begin
  if coalesce(trim(p_message_id), '') = '' then
    raise exception '[campo:message_id|tipo:obligatorio] message_id es obligatorio' using errcode = '22023';
  end if;
  if coalesce(trim(p_para), '') = '' then
    raise exception '[campo:para|tipo:obligatorio] para es obligatorio' using errcode = '22023';
  end if;
  if coalesce(trim(p_asunto), '') = '' then
    raise exception '[campo:asunto|tipo:obligatorio] asunto es obligatorio' using errcode = '22023';
  end if;

  if v_com is not null and not exists (select 1 from comunicacion where id = v_com) then
    raise exception '[campo:comunicacion_id|tipo:existente] La comunicación % no existe', v_com using errcode = '22023';
  end if;
  if v_com is null and coalesce(array_length(p_consecutivos, 1), 0) > 0 then
    select c.id into v_com
      from unnest(p_consecutivos) with ordinality as x(consecutivo, orden)
      join comunicacion c on c.consecutivo = x.consecutivo
     order by x.orden
     limit 1;
  end if;

  insert into correo_enviado (message_id, comunicacion_id, plantilla, para, asunto, cuerpo, archivo_ids, enviado_en)
  values (trim(p_message_id), v_com, p_plantilla, trim(p_para), p_asunto, p_cuerpo,
          coalesce(p_archivo_ids, '{}'), coalesce(p_enviado_en, now()))
  on conflict (message_id) do nothing
  returning id into v_id;

  if v_id is null then
    select id, comunicacion_id into v_id, v_com from correo_enviado where message_id = trim(p_message_id);
    return jsonb_build_object('id', v_id, 'comunicacion_id', v_com, 'duplicado', true);
  end if;
  return jsonb_build_object('id', v_id, 'comunicacion_id', v_com, 'duplicado', false);
end $$;

-- Solo el backend (service_role) puede llamarla.
revoke execute on function n8n_registrar_correo_enviado(text, text, text, text, text, bigint, text[], uuid[], timestamptz) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function n8n_registrar_correo_enviado(text, text, text, text, text, bigint, text[], uuid[], timestamptz) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function n8n_registrar_correo_enviado(text, text, text, text, text, bigint, text[], uuid[], timestamptz) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function n8n_registrar_correo_enviado(text, text, text, text, text, bigint, text[], uuid[], timestamptz) to service_role';
    execute 'grant select, insert on table correo_enviado to service_role';
  end if;
end $$;

notify pgrst, 'reload schema';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261015000000_varias_respuestas_dependencia.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  15 Varias respuestas de la dependencia a una misma comunicación
--
--  Problema: n8n_registrar_respuesta_dependencia (migración 09) asumía una sola
--  respuesta. Con la primera, el cambio de estado crea el evento
--  "respuesta_dependencia" y se le pone el correo. Con la segunda (otra persona de
--  la dependencia, o un complemento) el estado ya es "respondida_dependencia": no
--  se crea evento, el adjunto se cuelga del evento del primer correo y el texto
--  del segundo se pierde.
--
--  Solución: cada correo de respuesta es su propio evento, con su remitente, texto
--  y adjuntos. Idempotente por Message-ID (RN 12): si F1 reintenta el mismo correo,
--  no se duplica.
-- =============================================================================

create or replace function n8n_registrar_respuesta_dependencia(
  p_comunicacion_id bigint, p_de_correo text, p_asunto text, p_cuerpo text,
  p_message_id text, p_recibido_en text, p_archivo_ids uuid[], p_adjuntos_omitidos jsonb)
returns table(id bigint, consecutivo text, estado text)
language plpgsql as $$
#variable_conflict use_column
declare
  v_com comunicacion;
  v_evento bigint;
  v_detalle jsonb := jsonb_build_object(
    'de_correo', p_de_correo, 'asunto', p_asunto, 'cuerpo', p_cuerpo,
    'message_id_correo', p_message_id, 'recibido_en', p_recibido_en);
begin
  select * into v_com from comunicacion c where c.id = p_comunicacion_id for update;
  if not found then
    raise exception 'Comunicación % no existe', p_comunicacion_id using errcode = '23503';
  end if;

  -- El mismo correo ya se registró (reintento de F1): no se duplica.
  if nullif(trim(p_message_id), '') is not null then
    select e.id into v_evento from comunicacion_evento e
     where e.comunicacion_id = p_comunicacion_id and e.tipo = 'respuesta_dependencia'
       and e.message_id = p_message_id
     limit 1;
  end if;

  if v_evento is null then
    if v_com.estado = 'respondida_dependencia' then
      -- Ya había respuesta: este correo es una respuesta más (sin cambio de estado).
      insert into comunicacion_evento (comunicacion_id, tipo, estado_anterior, estado_nuevo, dependencia_id, message_id, detalle)
      values (p_comunicacion_id, 'respuesta_dependencia', v_com.estado, v_com.estado, v_com.dependencia_id,
              p_message_id, v_detalle || jsonb_build_object('respuesta_adicional', true))
      returning comunicacion_evento.id into v_evento;
    else
      -- Primera respuesta: el trigger valida la transición (RN-AC-09) y crea el evento.
      update comunicacion set estado = 'respondida_dependencia' where comunicacion.id = p_comunicacion_id;
      select max(e.id) into v_evento from comunicacion_evento e
       where e.comunicacion_id = p_comunicacion_id and e.tipo = 'respuesta_dependencia';
      update comunicacion_evento
         set message_id = p_message_id,
             detalle = coalesce(detalle, '{}'::jsonb) || v_detalle
       where comunicacion_evento.id = v_evento;
    end if;
  end if;

  insert into comunicacion_adjunto (comunicacion_id, evento_id, archivo_id)
  select p_comunicacion_id, v_evento, a from unnest(coalesce(p_archivo_ids, '{}')) as a
  on conflict do nothing;

  insert into comunicacion_evento (comunicacion_id, tipo, detalle)
  select p_comunicacion_id, 'nota',
         jsonb_build_object('motivo', 'adjuntos_no_guardados', 'adjuntos', p_adjuntos_omitidos)
  where coalesce(p_adjuntos_omitidos, '[]'::jsonb) <> '[]'::jsonb;

  return query select c.id, c.consecutivo, c.estado::text from comunicacion c where c.id = p_comunicacion_id;
end $$;

-- Solo el backend (service_role) puede llamarla.
revoke execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function n8n_registrar_respuesta_dependencia(bigint, text, text, text, text, text, uuid[], jsonb) to service_role';
  end if;
end $$;

notify pgrst, 'reload schema';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261016000000_anular_documento.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  16 Anular un documento del archivo (RF-AC-024)
--
--  El botón "Anular documento" de Clasificados solo cambiaba la pantalla. Esta función
--  lo hace real: el documento NO se borra (RN 6), queda en estado "anulado" con motivo,
--  quién y cuándo. La auditoría la registra sola el trigger de la migración 06
--  (accion = 'anular', con el usuario que fija fn_set_usuario_actual).
-- =============================================================================

create or replace function fn_anular_documento_usuario(
  p_usuario_id   bigint,
  p_documento_id bigint,
  p_motivo       text
)
returns documento
language plpgsql as $$
declare
  v documento;
begin
  perform fn_set_usuario_actual(p_usuario_id);

  if coalesce(trim(p_motivo), '') = '' then
    raise exception '[campo:motivo|tipo:obligatorio] RF-AC-024: el motivo de la anulación es obligatorio'
      using errcode = '22023';
  end if;

  select * into v from documento where id = p_documento_id for update;
  if not found then
    raise exception '[campo:id|tipo:existente] El documento % no existe', p_documento_id using errcode = '22023';
  end if;
  if v.estado = 'anulado' then
    raise exception '[campo:id|tipo:estado] RF-AC-024: el documento % ya está anulado', p_documento_id
      using errcode = 'P0001';
  end if;

  update documento
     set estado = 'anulado',
         anulado_motivo = trim(p_motivo),
         anulado_por = p_usuario_id,
         anulado_en = now(),
         actualizado_en = now()
   where id = p_documento_id
  returning * into v;

  return v;
end $$;

-- Solo el backend (service_role) puede llamarla.
revoke execute on function fn_anular_documento_usuario(bigint, bigint, text) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function fn_anular_documento_usuario(bigint, bigint, text) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function fn_anular_documento_usuario(bigint, bigint, text) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_anular_documento_usuario(bigint, bigint, text) to service_role';
  end if;
end $$;

notify pgrst, 'reload schema';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261017000000_catalogos_parametros_auditoria.sql
-- ═════════════════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261018000000_parametros_descripcion_usuario.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- SGD-090: las descripciones de los parámetros se muestran en pantalla (Catálogos › Parámetros).
-- Se reescriben en lenguaje de usuario, sin códigos de requisitos (RF/RN/RNF-AC, P-xx).
-- Solo cambia el texto: los valores configurados no se tocan.
update parametro p
   set descripcion = v.descripcion,
       actualizado_en = now()
  from (values
    ('anios_minimos_transferencia',     'Años que los documentos permanecen en la dependencia antes de poder transferirse al Archivo Central. Se transfiere hasta el año actual menos este número.'),
    ('tamano_maximo_archivo_mb',        'Tamaño máximo de cada archivo que se sube, en megabytes (MB).'),
    ('formatos_permitidos',             'Tipos de archivo que se pueden subir, escritos como extensiones separadas por coma (por ejemplo: pdf, docx, jpg).'),
    ('plazo_respuesta_dias_habiles',    'Días hábiles que tiene una dependencia para responder una comunicación que se le remitió.'),
    ('recordatorio_cada_dias_habiles',  'Días hábiles que deben pasar entre dos recordatorios de la misma comunicación.'),
    ('max_recordatorios_antes_escalar', 'Cantidad de recordatorios sin respuesta después de la cual la comunicación se marca para escalar.'),
    ('umbral_confianza_ia',             'Confianza mínima, de 0 a 1, para que una sugerencia de la inteligencia artificial se muestre como confiable. Por debajo se marca como de baja confianza.'),
    ('ia_habilitada',                   'Activa o desactiva las sugerencias de clasificación hechas con inteligencia artificial. Siempre requieren confirmación de una persona.'),
    ('buzon_archivo_central',           'Correo institucional del que se leen las comunicaciones que llegan al Archivo Central.')
  ) as v(clave, descripcion)
 where p.clave = v.clave
   and p.descripcion is distinct from v.descripcion;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261019000000_historico_comunicaciones.sql
-- ═════════════════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261020000000_archivo_busqueda.sql
-- ═════════════════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261021000000_clasificar_documento.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  21 Clasificar un documento (RF-AC-011)
--
--  El botón "Clasificar" de Por clasificar solo cambiaba la pantalla: el documento seguía
--  "por clasificar" y nunca llegaba a Clasificados ni al Archivo. Esta función guarda los
--  datos del documento y, con p_clasificar = true, exige los datos del F-02 (tipo, consecutivo,
--  fecha, caja, carpeta y asunto con su TRD). El estado lo sigue decidiendo el trigger
--  fn_trg_documento_preparar (asunto + fecha = clasificado); la auditoría la registra el
--  trigger de la migración 06 con el usuario que fija fn_set_usuario_actual. El archivo no se
--  mueve: la carpeta Dependencia → Año → Asunto es virtual (D-02).
--
--  También sirve para reclasificar un documento ya clasificado (queda auditado).
--  p_datos: { asunto_id, tipo (Entrada|Salida|Interno o ENT|SAL|INT), consecutivo, fecha (AAAA-MM-DD),
--             anio, remitente, destinatario, caja, carpeta, ubicacion_id, observaciones }.
--  Solo se cambian las claves que vienen en p_datos.
-- =============================================================================

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

-- Solo el backend (service_role) puede llamarla.
revoke execute on function fn_documento_clasificar(bigint, bigint, jsonb, boolean) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function fn_documento_clasificar(bigint, bigint, jsonb, boolean) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function fn_documento_clasificar(bigint, bigint, jsonb, boolean) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_documento_clasificar(bigint, bigint, jsonb, boolean) to service_role';
  end if;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261022000000_transferencia_archivos.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  22 Archivos de una transferencia digital (RF-AC-010)
--
--  Una transferencia digital trae el acta de entrega (el Excel de la dependencia,
--  transferencia.acta_archivo_id) y los documentos en digital. Esos documentos se
--  guardan con la transferencia, tal como llegaron: NO pasan a "Por clasificar".
--  Cada fila liga un archivo (tabla archivo, guardado en carpetas locales: D-02)
--  a su transferencia. Sin borrado físico (RN 6): se anula con motivo.
-- =============================================================================

create table if not exists transferencia_archivo (
  id                bigint generated always as identity primary key,
  transferencia_id  bigint not null references transferencia(id),
  archivo_id        uuid   not null unique references archivo(id),
  hash_sha256       char(64) not null,                      -- copia de archivo.hash_sha256 (duplicados)
  subido_por        bigint references usuario(id),
  subido_en         timestamptz not null default now(),
  anulado_motivo    text,
  anulado_por       bigint references usuario(id),
  anulado_en        timestamptz,
  constraint transferencia_archivo_anulacion_con_motivo check (anulado_en is null or anulado_motivo is not null)
);

-- El mismo archivo (misma huella) no se guarda dos veces en la misma transferencia.
create unique index if not exists transferencia_archivo_sin_duplicados
  on transferencia_archivo (transferencia_id, hash_sha256) where anulado_en is null;
create index if not exists transferencia_archivo_transferencia_idx on transferencia_archivo (transferencia_id);

-- Auditoría inmutable, igual que las demás tablas (migración 06).
do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'transferencia_archivo_auditar') then
    create trigger transferencia_archivo_auditar after insert or update on transferencia_archivo
      for each row execute function fn_trg_auditar_cambios();
  end if;
end $$;

-- Agrega un archivo (ya guardado en carpetas y en la tabla archivo) a una transferencia digital.
-- Fija el usuario para la auditoría, revisa el permiso y rechaza duplicados en la misma transferencia.
create or replace function fn_transferencia_agregar_archivo(
  p_usuario_id bigint, p_transferencia_id bigint, p_archivo_id uuid
)
returns jsonb
language plpgsql as $$
declare
  v_t    transferencia;
  v_hash char(64);
  v     transferencia_archivo;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  if not fn_catalogo_autorizar(p_usuario_id, 'cargas.transferencia', 'crear', 'transferencia_archivo', p_transferencia_id::text) then
    return jsonb_build_object('denegado', true, 'funcion', 'cargas.transferencia');
  end if;

  select * into v_t from transferencia where id = p_transferencia_id;
  if not found then
    raise exception '[campo:id|tipo:existente] La transferencia % no existe', p_transferencia_id using errcode = '22023';
  end if;
  if v_t.anulado_en is not null then
    raise exception '[campo:id|tipo:estado] La transferencia está anulada' using errcode = 'P0001';
  end if;
  if v_t.tipo <> 'digital' then
    raise exception '[campo:tipo|tipo:estado] Solo las transferencias digitales llevan archivos: las cajas de una física se quedan en bodega'
      using errcode = 'P0001';
  end if;

  select hash_sha256 into v_hash from archivo where id = p_archivo_id;
  if not found then
    raise exception '[campo:archivo|tipo:existente] El archivo no existe' using errcode = '22023';
  end if;

  begin
    insert into transferencia_archivo (transferencia_id, archivo_id, hash_sha256, subido_por)
    values (p_transferencia_id, p_archivo_id, v_hash, p_usuario_id)
    returning * into v;
  exception when unique_violation then
    raise exception '[campo:archivo|tipo:duplicado] Ese archivo ya está en esta transferencia' using errcode = '22023';
  end;
  return to_jsonb(v);
end $$;

revoke execute on function fn_transferencia_agregar_archivo(bigint, bigint, uuid) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function fn_transferencia_agregar_archivo(bigint, bigint, uuid) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function fn_transferencia_agregar_archivo(bigint, bigint, uuid) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_transferencia_agregar_archivo(bigint, bigint, uuid) to service_role';
  end if;
end $$;

-- Solo el backend (service_role): RLS activo y sin acceso para anon/authenticated.
alter table transferencia_archivo enable row level security;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on transferencia_archivo from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on transferencia_archivo from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant select, insert, update on transferencia_archivo to service_role';
  end if;
end $$;


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261023000000_ubicacion_carro_estante_bandeja.sql
-- ═════════════════════════════════════════════════════════════════════════════
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



-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261024000000_niveles_posgrado.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  24 Niveles de posgrado: especialización, maestría y doctorado (RF-AC-004, RF-AC-020)
--
--  nivel_academico solo tenía 'pregrado' y 'posgrado', pero Catálogos › Programas
--  académicos ofrece Especialización, Maestría y Doctorado: crear una especialización
--  fallaba con "invalid input value for enum nivel_academico". En Historias académicas,
--  al elegir Posgrado se listan las especializaciones (y maestrías y doctorados).
--  'posgrado' se conserva para los programas que ya lo usan.
-- =============================================================================

alter type nivel_academico add value if not exists 'especializacion';
alter type nivel_academico add value if not exists 'maestria';
alter type nivel_academico add value if not exists 'doctorado';

comment on type nivel_academico is 'pregrado; posgrado (genérico, registros viejos); especializacion, maestria y doctorado (posgrado).';


-- ═════════════════════════════════════════════════════════════════════════════
-- Migración: 20261025000000_historias_carga_busqueda.sql
-- ═════════════════════════════════════════════════════════════════════════════
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


-- ═════════════════════════════════════════════════════════════════════════════
-- Datos base: seed.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- =============================================================================
--  Datos iniciales obligatorios (configuración). Idempotente.
--  Los valores marcados "tentativo" están por confirmar con el cliente (P-14).
-- =============================================================================

-- ── Parámetros (RF-AC-006) ──────────────────────────────────────────────────
insert into parametro (clave, valor, tipo, descripcion, minimo, maximo) values
  ('anios_minimos_transferencia',     '2',   'entero',  'Años que los documentos permanecen en la dependencia antes de poder transferirse al Archivo Central. Se transfiere hasta el año actual menos este número.', 0, 10),
  ('tamano_maximo_archivo_mb',        '50',  'entero',  'Tamaño máximo de cada archivo que se sube, en megabytes (MB).', 1, 500),
  ('formatos_permitidos',             'pdf,jpg,jpeg,png,xlsx', 'lista', 'Tipos de archivo que se pueden subir, escritos como extensiones separadas por coma (por ejemplo: pdf, docx, jpg).', null, null),
  ('plazo_respuesta_dias_habiles',    '5',   'entero',  'Días hábiles que tiene una dependencia para responder una comunicación que se le remitió.', 1, 60),
  ('recordatorio_cada_dias_habiles',  '2',   'entero',  'Días hábiles que deben pasar entre dos recordatorios de la misma comunicación.', 1, 30),
  ('max_recordatorios_antes_escalar', '3',   'entero',  'Cantidad de recordatorios sin respuesta después de la cual la comunicación se marca para escalar.', 1, 10),
  ('umbral_confianza_ia',             '0.70','decimal', 'Confianza mínima, de 0 a 1, para que una sugerencia de la inteligencia artificial se muestre como confiable. Por debajo se marca como de baja confianza.', 0, 1),
  ('ia_habilitada',                   'false','booleano','Activa o desactiva las sugerencias de clasificación hechas con inteligencia artificial. Siempre requieren confirmación de una persona.', null, null),
  ('buzon_archivo_central',           'correspondencia@uniautonoma.edu.co', 'texto', 'Correo institucional del que se leen las comunicaciones que llegan al Archivo Central.', null, null)
on conflict (clave) do nothing;

-- ── Plantillas de correo (RF-AC-006) ────────────────────────────────────────
insert into plantilla_correo (codigo, nombre, asunto, cuerpo, cuerpo_original) values
  ('acuse_recibo', 'Acuse de recibo',
   '[SGD {consecutivo}] Recibimos su comunicación',
   E'Estimado(a) {nombre}:\n\nLe confirmamos que recibimos su comunicación sobre "{asunto}" el {fecha}. Quedó registrada con el consecutivo {consecutivo}.\n\nPara cualquier consulta, responda este correo sin modificar el asunto.\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca',
   E'Estimado(a) {nombre}:\n\nLe confirmamos que recibimos su comunicación sobre "{asunto}" el {fecha}. Quedó registrada con el consecutivo {consecutivo}.\n\nPara cualquier consulta, responda este correo sin modificar el asunto.\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca'),
  ('remision', 'Remisión a dependencia',
   '[SGD {consecutivo}] {asunto}',
   E'Señores {dependencia}:\n\nRemitimos la comunicación {consecutivo} sobre "{asunto}" para su atención. Plazo de respuesta: {plazo}.\n\n{mensaje}\n\nResponda este correo sin modificar el asunto.\n\nArchivo Central',
   E'Señores {dependencia}:\n\nRemitimos la comunicación {consecutivo} sobre "{asunto}" para su atención. Plazo de respuesta: {plazo}.\n\n{mensaje}\n\nResponda este correo sin modificar el asunto.\n\nArchivo Central'),
  ('devolucion', 'Devolución a dependencia',
   '[SGD {consecutivo}] Respuesta incompleta: {asunto}',
   E'Señores {dependencia}:\n\nLa respuesta a la comunicación {consecutivo} sobre "{asunto}" está incompleta:\n\n{mensaje}\n\nPor favor compleméntela respondiendo este correo sin modificar el asunto.\n\nArchivo Central',
   E'Señores {dependencia}:\n\nLa respuesta a la comunicación {consecutivo} sobre "{asunto}" está incompleta:\n\n{mensaje}\n\nPor favor compleméntela respondiendo este correo sin modificar el asunto.\n\nArchivo Central'),
  ('respuesta', 'Respuesta al remitente',
   '[SGD {consecutivo}] Respuesta a su comunicación',
   E'Estimado(a) {nombre}:\n\nEn atención a su comunicación {consecutivo} sobre "{asunto}", le informamos:\n\n{respuesta}\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca',
   E'Estimado(a) {nombre}:\n\nEn atención a su comunicación {consecutivo} sobre "{asunto}", le informamos:\n\n{respuesta}\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca'),
  ('recordatorio', 'Recordatorio a dependencia',
   'Comunicaciones pendientes de respuesta',
   E'Señores {dependencia}:\n\nLas siguientes comunicaciones superaron su plazo de respuesta:\n\n{pendientes}\n\nResponda cada una desde su correo original sin modificar el asunto.\n\nArchivo Central',
   E'Señores {dependencia}:\n\nLas siguientes comunicaciones superaron su plazo de respuesta:\n\n{pendientes}\n\nResponda cada una desde su correo original sin modificar el asunto.\n\nArchivo Central'),
  ('resumen', 'Resumen diario para Archivo Central',
   'Resumen diario de comunicaciones — {fecha}',
   E'Resumen del {fecha}:\n\n{respuesta}',
   E'Resumen del {fecha}:\n\n{respuesta}')
on conflict (codigo) do nothing;

-- ── Matriz de permisos por perfil (F-02 §2.3) ───────────────────────────────
insert into permiso_perfil (perfil, funcion) values
  -- Archivo Central: todo el módulo salvo usuarios y parámetros sensibles.
  ('archivo_central', 'catalogos.gestionar'),
  ('archivo_central', 'plantillas.gestionar'),
  ('archivo_central', 'cargas.documento'),
  ('archivo_central', 'cargas.transferencia'),
  ('archivo_central', 'cargas.historias'),
  ('archivo_central', 'cargas.historico'),
  ('archivo_central', 'transferencias.recibir'),
  ('archivo_central', 'documentos.clasificar'),
  ('archivo_central', 'documentos.consultar'),
  ('archivo_central', 'documentos.descargar'),
  ('archivo_central', 'ia.sugerir'),
  ('archivo_central', 'comunicaciones.gestionar'),
  ('archivo_central', 'comunicaciones.consultar'),
  ('archivo_central', 'historias.consultar'),
  ('archivo_central', 'historias.gestionar'),
  ('archivo_central', 'registros.anular'),
  -- Dependencia: transferir y consultar lo suyo (el filtro por dependencia lo hace fn_puede_ver_dependencia).
  ('dependencia', 'cargas.transferencia'),
  ('dependencia', 'documentos.consultar'),
  ('dependencia', 'comunicaciones.consultar'),
  -- Registro Académico: historias activas (el filtro por estado lo hace fn_puede_ver_historia).
  ('registro_academico', 'cargas.historias'),
  ('registro_academico', 'historias.consultar'),
  ('registro_academico', 'historias.gestionar'),
  -- Secretaría General: consulta.
  ('secretaria_general', 'documentos.consultar'),
  ('secretaria_general', 'comunicaciones.consultar'),
  ('secretaria_general', 'historias.consultar'),
  -- Administrador: catálogos, usuarios, parámetros y auditoría.
  ('administrador', 'catalogos.gestionar'),
  ('administrador', 'plantillas.gestionar'),
  ('administrador', 'usuarios.gestionar'),
  ('administrador', 'parametros.gestionar'),
  ('administrador', 'auditoria.consultar')
on conflict do nothing;
-- P-09 pendiente: qué perfiles pueden descargar. Por ahora solo Archivo Central.

-- ── Tipos documentales base (RF-AC-004) ─────────────────────────────────────
insert into tipo_documental (nombre)
select n from unnest(array['Acta','Memorando','Circular','Resolución','Comprobante de egreso',
                           'Convenio','Contrato','Informe','Oficio','Certificado','Factura']) n
where not exists (select 1 from tipo_documental t where lower(t.nombre) = lower(n));
