-- =============================================================================
--  33 RLS en nivel_formacion (RNF-AC-02)
--
--  La migración 27 creó nivel_formacion sin activar RLS: era la única tabla del esquema
--  sin RLS (lo marca la prueba "RLS activo en todas las tablas"). Sin políticas, solo el
--  dueño y el rol del backend (sgd_backend, que salta RLS) la leen y escriben, como el resto.
-- =============================================================================

alter table nivel_formacion enable row level security;
