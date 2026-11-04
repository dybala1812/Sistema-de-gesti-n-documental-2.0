-- =============================================================================
--  13 Validar el usuario que actúa (fn_set_usuario_actual)
--
--  Problema: si un flujo de n8n (o una prueba manual) manda un usuario_id que no existe
--  en la tabla `usuario`, la acción fallaba más adelante con
--  «insert or update on table "comunicacion_evento" violates foreign key constraint
--  "comunicacion_evento_usuario_id_fkey"», sin decir qué usuario ni qué campo.
--
--  Solución: todas las funciones del backend y de n8n llaman a fn_set_usuario_actual;
--  se valida ahí, una sola vez, y el error se devuelve con la etiqueta [campo:|tipo:]
--  que el backend ya traduce a un 400 claro. NULL sigue permitido (acción del sistema).
-- =============================================================================

create or replace function fn_set_usuario_actual(p_usuario_id bigint)
returns void
language plpgsql
as $$
begin
  if p_usuario_id is not null and not exists (select 1 from usuario where id = p_usuario_id) then
    raise exception '[campo:usuario|tipo:existente] El usuario % no existe en la tabla usuario: el usuario_id que envía el flujo debe ser el id del usuario de Archivo Central que realiza la acción', p_usuario_id
      using errcode = '22023';
  end if;
  perform set_config('app.usuario_id', coalesce(p_usuario_id::text, ''), true);
end;
$$;

notify pgrst, 'reload schema';
