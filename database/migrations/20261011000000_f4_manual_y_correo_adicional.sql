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
