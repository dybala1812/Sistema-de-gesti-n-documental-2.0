-- =============================================================================
--  24 Niveles de posgrado: especialización, maestría y doctorado (RF-AC-004, RF-AC-020)
--
--  nivel_academico solo tenía 'pregrado' y 'posgrado', pero Catálogos › Programas
--  académicos ofrece Especialización, Maestría y Doctorado: crear una especialización
--  fallaba con "invalid input value for enum nivel_academico". En Historias académicas,
--  al elegir Posgrado se listan las especializaciones (y maestrías y doctorados).
--  'posgrado' se conserva para los programas que ya lo usan.
-- =============================================================================

alter type nivel_academico add value if not exists 'especializacion';
alter type nivel_academico add value if not exists 'maestria';
alter type nivel_academico add value if not exists 'doctorado';

comment on type nivel_academico is 'pregrado; posgrado (genérico, registros viejos); especializacion, maestria y doctorado (posgrado).';
