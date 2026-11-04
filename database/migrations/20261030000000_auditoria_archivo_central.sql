-- =============================================================================
--  30 Archivo Central consulta la auditoría (D-28)
--
--  Antes solo el Administrador tenía auditoria.consultar. Ahora también el perfil principal,
--  Archivo Central, ve Administración › Auditoría. La auditoría sigue sin poder editarse ni
--  borrarse, y quien no tiene el permiso sigue quedando registrado como denegado.
-- =============================================================================

insert into permiso_perfil (perfil, funcion) values
  ('archivo_central', 'auditoria.consultar')
on conflict do nothing;
