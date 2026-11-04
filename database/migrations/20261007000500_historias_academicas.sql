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
