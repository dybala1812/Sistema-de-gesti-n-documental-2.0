# Tareas faltantes — SGD · Módulo Archivo Central

> Backlog: por agregar, corregir o investigar. Sale hacia `tareas-por-realizar.md`.
> Formato: `- [ ] SGD-001: descripción (HU-xxx, RF-xxx) · N pts` + metadata indentada.
> Campos opcionales: `Spec:`, `Tipo:`, `Prioridad:`, `Responsable:`, `Depende de:`, `Estimación:`, `Bloqueo:`.
> Orden sugerido: Arranque → Base → Catálogos → Cargas → Clasificación → Comunicaciones → Historias → PWA.
> Ordenado el 2026-10-27: lo implementado pasó a `tareas-en-revision.md`; lo que tiene avance parcial, a `tareas-por-realizar.md`. Las tareas de feature grandes se dividen en subtareas (a backend, b frontend, c pruebas) al promoverlas.

## Arranque

- [ ] SGD-031: Sugerencia de clasificación con IA — flujo F11, solo sugerir, auditar decisión (HU-AC-08, RF-AC-012) · 3 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-012
  Prioridad: baja
  Depende de: SGD-030, SGD-001 (P-13)

- [ ] SGD-032: Árbol Dependencia → Año → Asunto con contadores y búsqueda avanzada paginada (HU-AC-09, RF-AC-013, 014) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-013
  Prioridad: alta
  Depende de: SGD-030
  Nota: la pantalla Archivo usa datos de ejemplo escritos en el código

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
