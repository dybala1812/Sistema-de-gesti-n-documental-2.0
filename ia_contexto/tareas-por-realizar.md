# Tareas por realizar — Sistema de Gestión Documental (SGD)

> Seleccionadas y listas para implementar. Sale hacia tareas-en-revision.md.
> Aquí están las que ya tienen avance parcial: `Avance:` dice lo hecho y `Falta:` lo que falta para pasarlas a revisión.

## Bugs reportados (2026-10-27)

- [ ] SGD-090: [BUG] Parámetros: las descripciones en pantalla citan códigos de requisitos (RNF, RF, RN)
  Tipo: bug
  Prioridad: media
  Etiquetas: bug, parametros, ux
  Skills: desarrollo
  Relacionado: SGD-012
  Pasos para reproducir: 1. Abrir Archivo Central › Catálogos › Parámetros. 2. Leer el texto de cada valor (es el campo descripcion de la base).
  Esperado: cada parámetro se explica en lenguaje de usuario (qué hace y para qué sirve). Sin códigos RNF-AC, RF-AC, RN-AC, P-xx ni jerga de documentos de requisitos.
  Actual: el seed pone textos como «RNF-AC-08: tamaño máximo…», «RF-AC-016: plazo…», «RN-AC-03: años en archivo…», «RF-AC-012: … (P-13)». ParametrosPanel.tsx muestra esa descripcion como título.
  Archivos: database/supabase/seed.sql (y una migración que actualice descripcion en bases ya sembradas); NOVA_FT/src/app/pages/archivo-central/ParametrosPanel.tsx si hay textos fijos.

- [ ] SGD-020: Centro de cargas: asistente de 4 pasos, lotes con avance, informe descargable y reintento de fallidos (HU-AC-04, RF-AC-007) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-007
  Prioridad: alta
  Depende de: SGD-008
  Avance: pantallas de las cargas A, D y E y del detalle del lote, ya subidas
  Falta: lotes reales en el backend: el avance, el informe y el reintento son simulados y el código del lote es fijo (L-2026-044/045)

- [ ] SGD-043: Recordatorios en días hábiles (F4), resumen diario y correos sin asociar (HU-AC-13, RF-AC-018) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-018
  Prioridad: media
  Depende de: SGD-041, SGD-001 (P-15)
  Avance: recordatorio manual, correo adicional y bandeja de correos sin asociar
  Falta: importar y activar F4 diario (flujos n8n/F4_recordatorios_api.json) con el resumen diario

- [ ] SGD-044: Histórico de comunicaciones en calendario e importación idempotente de Excel 2024/2025/2026 (F10) (HU-AC-14, RF-AC-019) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-019
  Prioridad: alta
  Depende de: SGD-007
  Avance: pantalla de Registro histórico
  Falta: importación idempotente de los Excel 2024/2025/2026 (F10)

- [ ] SGD-023: Transferencia digital: FUID + archivos por asunto, multi-sesión (HU-AC-07, RF-AC-010) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-010
  Prioridad: alta
  Depende de: SGD-021, SGD-022
  Nota: el asistente de Transferencias acepta el tipo «digital» pero no sube los archivos por asunto
