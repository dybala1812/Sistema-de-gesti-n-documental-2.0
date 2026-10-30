-- =============================================================================
--  26 Permiso por recurso al descargar un archivo (RF-AC-023, RN-AC-06, Ley 1581)
--
--  GET /api/archivos/{id} entregaba cualquier archivo a cualquier usuario con sesión que
--  conociera el UUID. fn_archivo_puede_descargar revisa a qué pertenece el archivo y exige el
--  permiso de ese recurso; basta con que UNO de sus dueños lo permita:
--    - quien lo subió (para verlo justo después de cargarlo);
--    - documento: documentos.consultar o documentos.clasificar + fn_puede_ver_dependencia;
--    - historia_documento: historias.consultar o cargas.historias + fn_puede_ver_historia
--      (Registro Académico solo historias activas; Archivo Central y Secretaría General, todas);
--    - adjunto o copia de correo de una comunicación: comunicaciones.consultar + su dependencia
--      (sin dependencia asignada, solo perfiles que no son Dependencia);
--    - acta, FUID o archivo de una transferencia: cargas.transferencia, transferencias.recibir o
--      documentos.consultar + fn_puede_ver_dependencia de la transferencia;
--    - informe o archivo de un lote de carga: quien creó el lote o Archivo Central.
--  Un archivo sin dueño conocido solo lo ve quien lo subió. El intento denegado queda en la
--  auditoría (accion 'descargar', resultado 'denegado'). n8n (token de servicio) no pasa por aquí.
-- =============================================================================

create or replace function fn_archivo_puede_descargar(p_usuario_id bigint, p_archivo_id uuid)
returns boolean
language plpgsql
as $$
declare
  v_ok     boolean := false;
  v_perfil perfil_usuario;
begin
  perform fn_set_usuario_actual(p_usuario_id);
  select perfil into v_perfil from usuario where id = p_usuario_id and fn_usuario_puede_ingresar(id);

  if v_perfil is not null then
    v_ok :=
      exists (select 1 from archivo a where a.id = p_archivo_id and a.subido_por = p_usuario_id)
      or exists (
        select 1 from documento d
         where d.archivo_id = p_archivo_id
           and (fn_tiene_permiso(p_usuario_id, 'documentos.consultar') or fn_tiene_permiso(p_usuario_id, 'documentos.clasificar'))
           and fn_puede_ver_dependencia(p_usuario_id, d.dependencia_id))
      or exists (
        select 1 from historia_documento hd
         where hd.archivo_id = p_archivo_id
           and (fn_tiene_permiso(p_usuario_id, 'historias.consultar') or fn_tiene_permiso(p_usuario_id, 'cargas.historias'))
           and fn_puede_ver_historia(p_usuario_id, hd.historia_id))
      or (fn_tiene_permiso(p_usuario_id, 'comunicaciones.consultar') and exists (
        select 1 from comunicacion c
         where (c.id in (select ca.comunicacion_id from comunicacion_adjunto ca where ca.archivo_id = p_archivo_id)
                or c.id in (select ce.comunicacion_id from correo_enviado ce where p_archivo_id = any (ce.archivo_ids)))
           and (case when c.dependencia_id is null then v_perfil <> 'dependencia'
                     else fn_puede_ver_dependencia(p_usuario_id, c.dependencia_id) end)))
      or ((fn_tiene_permiso(p_usuario_id, 'cargas.transferencia') or fn_tiene_permiso(p_usuario_id, 'transferencias.recibir')
           or fn_tiene_permiso(p_usuario_id, 'documentos.consultar')) and exists (
        select 1 from transferencia t
         where (t.acta_archivo_id = p_archivo_id or t.fuid_archivo_id = p_archivo_id
                or t.id in (select ta.transferencia_id from transferencia_archivo ta where ta.archivo_id = p_archivo_id))
           and fn_puede_ver_dependencia(p_usuario_id, t.dependencia_id)))
      or exists (
        select 1 from lote_carga l
         where (l.informe_archivo_id = p_archivo_id
                or l.id in (select li.lote_id from lote_item li where li.archivo_id = p_archivo_id))
           and (l.creado_por = p_usuario_id or v_perfil = 'archivo_central'));
  end if;

  if not v_ok then
    insert into auditoria (usuario_id, accion, recurso_tipo, recurso_id, resultado, detalle)
    values (p_usuario_id, 'descargar', 'archivo', p_archivo_id::text, 'denegado',
            jsonb_build_object('motivo', 'sin permiso sobre el recurso del archivo'));
  end if;
  return v_ok;
end $$;

-- Solo el backend (service_role) la llama.
revoke execute on function fn_archivo_puede_descargar(bigint, uuid) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke execute on function fn_archivo_puede_descargar(bigint, uuid) from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke execute on function fn_archivo_puede_descargar(bigint, uuid) from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function fn_archivo_puede_descargar(bigint, uuid) to service_role';
  end if;
end $$;
