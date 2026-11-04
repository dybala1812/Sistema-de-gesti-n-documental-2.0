-- =============================================================================
--  11 Datos de Gmail en la comunicación
--  gmail_thread_id : hilo de Gmail donde se conversa el trámite (uno por comunicación).
--  ultimo_envio_id : Message-ID del último correo que envió Archivo Central
--                    (remisión, devolución, acuse o recordatorio); se sobrescribe en cada envío.
--  No son llaves foráneas: son identificadores que genera Gmail, no filas de otra tabla.
-- =============================================================================

alter table comunicacion
  add column if not exists gmail_thread_id text,
  add column if not exists ultimo_envio_id text;

comment on column comunicacion.gmail_thread_id is 'Hilo de Gmail del trámite (threadId). Permite asociar respuestas aunque borren la etiqueta del asunto.';
comment on column comunicacion.ultimo_envio_id is 'Message-ID del último correo enviado por Archivo Central. Se actualiza solo desde comunicacion_evento.';

create index if not exists comunicacion_gmail_thread_idx
  on comunicacion (gmail_thread_id) where gmail_thread_id is not null;

-- ultimo_envio_id se mantiene solo: cada vez que un evento de envío guarda su
-- message_id, se copia a la comunicación. Así nunca queda desincronizado.
create or replace function fn_trg_evento_ultimo_envio()
returns trigger
language plpgsql
as $$
begin
  if new.message_id is not null
     and new.tipo in ('acuse_recibo', 'remision', 'devolucion', 'recordatorio', 'marcada_escalar') then
    update comunicacion
       set ultimo_envio_id = new.message_id
     where id = new.comunicacion_id
       and ultimo_envio_id is distinct from new.message_id;
  end if;
  return null;
end;
$$;

drop trigger if exists comunicacion_evento_ultimo_envio on comunicacion_evento;
create trigger comunicacion_evento_ultimo_envio
after insert or update of message_id on comunicacion_evento
for each row execute function fn_trg_evento_ultimo_envio();

-- Rellena las comunicaciones que ya tienen envíos registrados.
update comunicacion c
   set ultimo_envio_id = e.message_id
  from (
    select distinct on (comunicacion_id) comunicacion_id, message_id
    from comunicacion_evento
    where message_id is not null
      and tipo in ('acuse_recibo', 'remision', 'devolucion', 'recordatorio', 'marcada_escalar')
    order by comunicacion_id, creado_en desc, id desc
  ) e
 where c.id = e.comunicacion_id;
