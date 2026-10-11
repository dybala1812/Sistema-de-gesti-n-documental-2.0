# Tareas en revision — Sistema de Gestión Documental (SGD)

> Implementadas; falta verificación o revisión humana. Anotar Evidencia: y Pendiente:.

<!-- Ejemplo:
- [ ] SGD-005: Esquema de base de datos
  Spec: ia_contexto/spec/requirements.md#rf-003
  Evidencia: scripts sin errores; pruebas 26/26 OK
  Pendiente: ejecutarlo en el entorno de producción
-->

- [ ] SGD-007: Esquema de base de datos en Supabase: tablas, restricciones únicas (hash, Message-ID, asunto por dependencia), RLS y función atómica de consecutivos ENT/SAL/INT con reinicio anual (RN-AC-08) + pruebas de concurrencia
  Spec: ia_contexto/spec/architecture.md#entidades-principales
  Tipo: feature
  Prioridad: alta
  Depende de: SGD-001 (P-10, P-11)
  Evidencia: backned_sistema_gestion_documental/scripts/probar_local.sh en PostgreSQL 18 temporal — 6 migraciones OK, seeds idempotentes, 79 verificaciones OK (pruebas_reglas.sql), 40 consecutivos concurrentes sin repetir.
  Pendiente: revisión humana; aplicar en el proyecto Supabase real; validar supuestos P-09, P-10, P-15, P-17, P-18.

- [ ] SGD-080: Frontend del módulo Comunicaciones en el Panel de Área de NOVA — Bandeja, detalle con Remitir/Devolver/Responder/Anular, Correos sin asociar y Registro histórico (HU-AC-10 a HU-AC-14, RF-AC-015 a 019)
  Spec: ia_contexto/spec/requirements.md#rf-ac-015
  Tipo: feature
  Archivos: NOVA_FT/src/app/pages/comunicaciones/*, NOVA_FT/src/app/lib/comunicacionesApi.ts (datos simulados), AreaDashboard.tsx (nuevo módulo en barra lateral y móvil)
  Evidencia: tsc sin errores en los archivos del módulo; probado en navegador (localhost:5180, sesión dev rol area): remitir, responder (crea SAL y cierra), asociar correo, histórico por mes, vista móvil sin desbordamiento.
  Pendiente: conectar al backend (reemplazar funciones api* de comunicacionesApi.ts); plantillas de correo; permisos por perfil del módulo; revisión humana.
