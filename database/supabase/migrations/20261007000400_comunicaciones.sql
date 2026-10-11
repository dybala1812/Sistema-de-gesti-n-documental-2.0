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
