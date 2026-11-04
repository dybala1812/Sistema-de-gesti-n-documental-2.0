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
