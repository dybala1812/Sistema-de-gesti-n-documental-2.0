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
