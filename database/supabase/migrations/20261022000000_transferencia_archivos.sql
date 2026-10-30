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
