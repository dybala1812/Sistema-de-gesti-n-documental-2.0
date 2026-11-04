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
