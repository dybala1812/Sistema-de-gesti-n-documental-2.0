# Memoria del Proyecto — Sistema de Gestión Documental (SGD)

Memoria viva: decisiones, riesgos y aprendizajes que deben sobrevivir entre sesiones.

## Estado actual

Especificación F-02 v1.1 (2026-10-07) volcada a `ia_contexto/spec/`. Sin código del módulo aún: falta firma del cliente (SGD-000), validar maquetas (SGD-002) y decidir backend/autenticación (P-11, P-12, P-16). Frontend base: `NOVA_FT/`.

## Decisiones tomadas

<!-- Formato: - AAAA-MM-DD — Decisión. Motivo. -->
- 2026-10-07 — Decisiones vinculantes del F-02 registradas en `ia_contexto/spec/decisiones.md` (D-01 a D-12): Supabase, archivos locales en carpetas referenciados por id en BD, n8n, consecutivos atómicos, perfiles fijos, sin borrado, IA solo sugiere.

## Riesgos conocidos

<!-- Formato: - Riesgo — impacto — tarea que lo atiende (si existe). -->
- El circuito de correo podría duplicar el sistema de radicación existente — alcance de RF-AC-015 a 019 — SGD-001 (P-01).
- Almacenamiento de ~600 GB para historias sin confirmar — RF-AC-021 — SGD-001 (P-05).
- Proveedor de correo sin definir (Google/M365) — bloquea F1–F5 — SGD-001 (P-02).
- Backend sin tecnología decidida y NOVA usa Django — arquitectura — SGD-001 (P-11).
- Envío de datos personales a IA externa — Ley 1581 — SGD-001 (P-13).

## Próximos candidatos de mejora

-

## Registro

- Kit de skills adaptado con `project-setup` (fecha: <!-- COMPLETAR -->).
