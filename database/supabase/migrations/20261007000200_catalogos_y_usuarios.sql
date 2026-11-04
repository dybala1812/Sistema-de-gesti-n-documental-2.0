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
