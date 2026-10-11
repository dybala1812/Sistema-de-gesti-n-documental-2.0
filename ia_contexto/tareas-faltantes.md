# Tareas faltantes — SGD · Módulo Archivo Central

> Backlog: por agregar, corregir o investigar. Sale hacia `tareas-por-realizar.md`.
> Formato: `- [ ] SGD-001: descripción (HU-xxx, RF-xxx) · N pts` + metadata indentada.
> Campos opcionales: `Spec:`, `Tipo:`, `Prioridad:`, `Responsable:`, `Depende de:`, `Estimación:`, `Bloqueo:`.
> Orden sugerido: Arranque → Base → Catálogos → Cargas → Clasificación → Comunicaciones → Historias → PWA. Las tareas de feature grandes se dividen en subtareas (a backend, b frontend, c pruebas) al promoverlas.

## Arranque

- [ ] SGD-000: Obtener la firma del F-02 v1.1 por el cliente (numeral 9) — requisito para iniciar construcción
  Spec: ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx
  Tipo: docs
  Prioridad: alta
  Bloqueo: depende del cliente

- [ ] SGD-001: Resolver las preguntas abiertas P-01 a P-16 de spec/decisiones.md (prioridad: P-01, P-02, P-11, P-12, P-16)
  Spec: ia_contexto/spec/decisiones.md
  Tipo: docs
  Prioridad: alta

- [ ] SGD-002: Validar con la jefatura los mockups (ia_contexto/diseno/mockups_archivo_central_y_movil.html) y resolver las diferencias I-08 a I-16
  Spec: ia_contexto/spec/product.md#pantallas-validar-maquetas-antes-de-desarrollar
  Tipo: docs
  Prioridad: alta

- [ ] SGD-003: Copiar a ia_contexto/fuentes/ el doc "Flujos n8n — Archivo Central", los SQL y JSON de n8n existentes y el F-03; actualizar spec/architecture.md
  Tipo: docs
  Prioridad: media

- [ ] SGD-004: Completar las skills del proyecto con project-setup (comandos de lint/test/build del backend y frontend, rama de desarrollo, estructura real)
  Depende de: SGD-001 (P-11, P-12)
  Tipo: chore
  Prioridad: media

## Base técnica

- [ ] SGD-005: Permisos por perfil y dependencia, auditoría inmutable y anulación sin borrado (HU-AC-18, RF-AC-023, RF-AC-024) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-023
  Tipo: feature
  Prioridad: alta
  Depende de: SGD-007, SGD-008

- [ ] SGD-006: Alinear NOVA_FT/src/styles/theme.css a la paleta institucional (I-04)
  Spec: .claude/skills/frontend/color-palette.md
  Tipo: refactor
  Prioridad: media

- [ ] SGD-008: Estructura del backend y frontend del módulo, autenticación y servicio de archivos locales en carpetas, tabla `archivo` con id de referencia (SHA-256, descarga autenticada por id), endpoints `POST/GET /api/archivos` para n8n con token de servicio (contrato en backned_sistema_gestion_documental/n8n/TABLAS_N8N.md) (RN-AC-14, RNF-AC-02)
  Tipo: feature
  Prioridad: alta
  Depende de: SGD-001 (P-11, P-12, P-16)

## Catálogos

- [ ] SGD-010: Dependencias, TRD y asuntos por dependencia con importación Excel e inactivación (HU-AC-01, RF-AC-001, 002, 003) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-001
  Prioridad: alta
  Depende de: SGD-005

- [ ] SGD-011: Tipos documentales, programas académicos y ubicaciones físicas (HU-AC-02, RF-AC-004) · 3 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-004
  Prioridad: media
  Depende de: SGD-010

- [ ] SGD-012: Usuarios y perfiles, parámetros y plantillas de correo con vista previa (HU-AC-03, RF-AC-005, 006) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-005
  Prioridad: alta
  Depende de: SGD-005

## Cargas y transferencias

- [ ] SGD-020: Centro de cargas: asistente de 4 pasos, lotes con avance, informe descargable y reintento de fallidos (HU-AC-04, RF-AC-007) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-007
  Prioridad: alta
  Depende de: SGD-008

- [ ] SGD-021: Carga de documento individual con hash y detección de duplicados — flujo F8 (HU-AC-05, RF-AC-008) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-008
  Prioridad: alta
  Depende de: SGD-020, SGD-010

- [ ] SGD-022: Transferencia física: lectura del FUID (F7), inventario por caja, regla año − 2, estado "recibida" (HU-AC-06, RF-AC-009) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-009
  Prioridad: alta
  Depende de: SGD-020, SGD-001 (P-04)

- [ ] SGD-023: Transferencia digital: FUID + archivos por asunto, multi-sesión (HU-AC-07, RF-AC-010) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-010
  Prioridad: alta
  Depende de: SGD-021, SGD-022

## Clasificación, archivo y búsqueda

- [ ] SGD-030: Bandejas Por clasificar / Clasificados con visor PDF + formulario, propuesta de TRD y reclasificación auditada (HU-AC-08, RF-AC-011) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-011
  Prioridad: alta
  Depende de: SGD-021

- [ ] SGD-031: Sugerencia de clasificación con IA — flujo F11, solo sugerir, auditar decisión (HU-AC-08, RF-AC-012) · 3 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-012
  Prioridad: baja
  Depende de: SGD-030, SGD-001 (P-13)

- [ ] SGD-032: Árbol Dependencia → Año → Asunto con contadores y búsqueda avanzada paginada (HU-AC-09, RF-AC-013, 014) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-013
  Prioridad: alta
  Depende de: SGD-030

## Comunicaciones por correo

- [ ] SGD-040: Recepción automática de correos — flujo F1, Message-ID, consecutivo ENT, acuse de recibo, bandeja por estados (HU-AC-10, RF-AC-015) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-015
  Prioridad: alta
  Depende de: SGD-007, SGD-012, SGD-001 (P-01, P-02)

- [ ] SGD-041: Remitir a dependencia (F2) y registrar su respuesta (F1, etiqueta / In-Reply-To), devolver (HU-AC-11, RF-AC-016) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-016
  Prioridad: alta
  Depende de: SGD-040

- [ ] SGD-042: Responder al remitente (F3), crear SAL enlazada y cerrar (HU-AC-12, RF-AC-017) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-017
  Prioridad: alta
  Depende de: SGD-041

- [ ] SGD-043: Recordatorios en días hábiles (F4), resumen diario y correos sin asociar (HU-AC-13, RF-AC-018) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-018
  Prioridad: media
  Depende de: SGD-041, SGD-001 (P-15)

- [ ] SGD-044: Histórico de comunicaciones en calendario e importación idempotente de Excel 2024/2025/2026 (F10) (HU-AC-14, RF-AC-019) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-019
  Prioridad: alta
  Depende de: SGD-007

## Historias académicas

- [ ] SGD-050: Árbol de historias Estado → Año → Nivel → Programa, ficha del estudiante, permisos RA vs AC (HU-AC-15, RF-AC-020) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-020
  Prioridad: alta
  Depende de: SGD-011

- [ ] SGD-051: Carga masiva de historias por carpetas (F9), pausable, ~30.000 historias (HU-AC-16, RF-AC-021) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-021
  Prioridad: alta
  Depende de: SGD-050, SGD-020, SGD-001 (P-03, P-05)

## App móvil

- [ ] SGD-060: PWA de escaneo multipágina con recorte automático y subida (HU-AC-17, RF-AC-022) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-022
  Prioridad: media
  Depende de: SGD-021

## Calidad transversal

- [ ] SGD-070: Pruebas de RNF: carga (< 3 s con 50.000 docs), reprocesamiento de correos (0 duplicados), respaldo/restauración, cobertura ≥ 60 % en consecutivos, estados y permisos
  Spec: ia_contexto/spec/requirements.md#requisitos-no-funcionales
  Tipo: test
  Prioridad: media
