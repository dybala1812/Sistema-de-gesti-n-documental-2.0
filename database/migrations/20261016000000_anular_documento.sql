-- =============================================================================
--  16 Anular un documento del archivo (RF-AC-024)
--
--  El botón "Anular documento" de Clasificados solo cambiaba la pantalla. Esta función
--  lo hace real: el documento NO se borra (RN 6), queda en estado "anulado" con motivo,
--  quién y cuándo. La auditoría la registra sola el trigger de la migración 06
--  (accion = 'anular', con el usuario que fija fn_set_usuario_actual).
-- =============================================================================

create or replace function fn_anular_documento_usuario(
  p_usuario_id   bigint,
  p_documento_id bigint,
  p_motivo       text
)
returns documento
language plpgsql as $$
declare
  v documento;
begin
  perform fn_set_usuario_actual(p_usuario_id);

  if coalesce(trim(p_motivo), '') = '' then
    raise exception '[campo:motivo|tipo:obligatorio] RF-AC-024: el motivo de la anulación es obligatorio'
      using errcode = '22023';
  end if;

  select * into v from documento where id = p_documento_id for update;
  if not found then
    raise exception '[campo:id|tipo:existente] El documento % no existe', p_documento_id using errcode = '22023';
  end if;
  if v.estado = 'anulado' then
    raise exception '[campo:id|tipo:estado] RF-AC-024: el documento % ya está anulado', p_documento_id
      using errcode = 'P0001';
  end if;

  update documento
     set estado = 'anulado',
         anulado_motivo = trim(p_motivo),
         anulado_por = p_usuario_id,
         anulado_en = now(),
         actualizado_en = now()
   where id = p_documento_id
  returning * into v;

  return v;
end $$;

-- Solo el backend (service_role) puede llamarla.
revoke execute on function fn_anular_documento_usuario(bigint, bigint, text) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function fn_anular_documento_usuario(bigint, bigint, text) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function fn_anular_documento_usuario(bigint, bigint, text) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_anular_documento_usuario(bigint, bigint, text) to service_role';
  end if;
end $$;

notify pgrst, 'reload schema';
