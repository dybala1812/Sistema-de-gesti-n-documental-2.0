-- =============================================================================
--  29 Registro Académico consulta todas las historias académicas (D-27)
--
--  Antes Registro Académico solo veía las historias activas. Ahora también ve las de
--  graduados y retirados (también las antiguas), igual que Archivo Central y Secretaría
--  General. La CUSTODIA no cambia (RN-AC-06): historia_academica.custodia sigue siendo
--  'registro_academico' para las activas y 'archivo_central' para graduados y retirados.
--  Afecta todo lo que usa fn_puede_ver_historia: árbol, lista y ficha de historias,
--  Consulta › Buscar y la descarga de sus archivos (migración 26).
-- =============================================================================

create or replace function fn_puede_ver_historia(p_usuario_id bigint, p_historia_id bigint)
returns boolean
language sql stable
as $$
  select exists (
    select 1
    from usuario u, historia_academica h
    where u.id = p_usuario_id and h.id = p_historia_id
      and fn_usuario_puede_ingresar(u.id)
      and u.perfil in ('archivo_central', 'secretaria_general', 'registro_academico')
  )
$$;
