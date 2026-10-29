# Tareas por realizar — Sistema de Gestión Documental (SGD)

> Seleccionadas y listas para implementar. Sale hacia tareas-en-revision.md.
> Aquí están las que ya tienen avance parcial: `Avance:` dice lo hecho y `Falta:` lo que falta para pasarlas a revisión.

## Antes del despliegue

- [ ] SGD-091: Quitar el login temporal de pruebas por perfil (/login-temporal) y dejar solo el token de NOVA
  Tipo: chore
  Prioridad: alta (bloquea el despliegue)
  Etiquetas: seguridad, despliegue
  Skills: seguridad, desarrollo
  Requisito: regla 10 de CLAUDE.md (sin login propio), D-13
  Pasos: seguir la lista de ia_contexto/login-temporal.md (todo está marcado con ⚠️ TEMPORAL), quitar las variables de los .env y comprobar que el build de producción no contiene login-temporal ni sgdtmp.
  Nota: rotar N8N_SERVICE_TOKEN (también en la credencial de n8n): estuvo en un build local del frontend antes del 2026-10-28.

## Bugs reportados (2026-10-27)

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

- [ ] SGD-023: Transferencia digital: FUID + archivos por asunto, multi-sesión (HU-AC-07, RF-AC-010) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-010
  Prioridad: alta
  Depende de: SGD-021, SGD-022
  Nota: el asistente de Transferencias acepta el tipo «digital» pero no sube los archivos por asunto


- [ ] SGD-050: Árbol de historias Estado → Año → Nivel → Programa, ficha del estudiante, permisos RA vs AC (HU-AC-15, RF-AC-020) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-020
  Prioridad: alta
  Depende de: SGD-011

- [ ] SGD-051: Carga masiva de historias por carpetas (F9), pausable, ~30.000 historias (HU-AC-16, RF-AC-021) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-021
  Prioridad: alta
  Depende de: SGD-050, SGD-020, SGD-001 (P-03, P-05)

- [ ] SGD-060: PWA de escaneo multipágina con recorte automático y subida (HU-AC-17, RF-AC-022) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-022
  Prioridad: media
  Depende de: SGD-021

- [ ] SGD-070: Pruebas de RNF: carga (< 3 s con 50.000 docs), reprocesamiento de correos (0 duplicados), respaldo/restauración, cobertura ≥ 60 % en consecutivos, estados y permisos
  Spec: ia_contexto/spec/requirements.md#requisitos-no-funcionales
  Tipo: test
  Prioridad: media
