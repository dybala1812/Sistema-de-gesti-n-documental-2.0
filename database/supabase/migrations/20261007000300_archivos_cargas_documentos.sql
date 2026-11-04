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
