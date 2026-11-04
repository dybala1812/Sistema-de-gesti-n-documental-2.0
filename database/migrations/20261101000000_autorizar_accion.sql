-- =============================================================================
--  32 Autorizar una acción y auditar el intento denegado, con el usuario que actúa
--
--  Para las rutas del backend que no pasan por una función SQL propia (p. ej. transferencias):
--  revisa el permiso y, si no lo tiene, deja el intento denegado en la auditoría con el usuario
--  y la acción (crear, consultar…). En una sola llamada, porque la auditoría toma el usuario
--  de la transacción (fn_set_usuario_actual).
-- =============================================================================

create or replace function fn_autorizar(
  p_usuario_id bigint, p_funcion text, p_accion text, p_recurso_tipo text, p_recurso_id text default null)
returns boolean
language plpgsql
as $$
begin
  perform fn_set_usuario_actual(p_usuario_id);
  return fn_catalogo_autorizar(p_usuario_id, p_funcion, p_accion, p_recurso_tipo, p_recurso_id);
end $$;

revoke execute on function fn_autorizar(bigint, text, text, text, text) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke execute on function fn_autorizar(bigint, text, text, text, text) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke execute on function fn_autorizar(bigint, text, text, text, text) from authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function fn_autorizar(bigint, text, text, text, text) to service_role;
  end if;
end $$;

notify pgrst, 'reload schema';
