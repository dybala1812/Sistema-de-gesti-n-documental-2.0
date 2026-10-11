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
