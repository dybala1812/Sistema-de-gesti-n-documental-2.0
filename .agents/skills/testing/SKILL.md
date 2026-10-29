---
name: testing
description: Estrategia, comandos y criterio de "verificado" de Sistema de Gestión Documental (SGD). Úsala para comprobar que una tarea está lista antes de cerrarla.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Testing — Sistema de Gestión Documental (SGD)

## Estado actual

- **Backend**: pruebas unitarias con `node --test` en `tests/` (`npm test`; Node 24 importa los `.ts` de `lib/` sin compilar), tipos con `tsc` y ESLint.
- **Base de datos**: `database/supabase/tests/pruebas_reglas.sql` prueba las reglas RN/RF en SQL; `probar_local.sh` aplica todas las migraciones en un PostgreSQL temporal, corre esas pruebas, revierte y mide la concurrencia de consecutivos (40 sesiones).
- **Frontend** `NOVA_FT/`: sin framework de tests ni linter; `npm run typecheck` (línea base 28 errores de NOVA) y `npx vite build`, más la verificación en el navegador.

## Verificación mínima obligatoria

```bash
# Backend — desde backned_sistema_gestion_documental/
npx tsc --noEmit -p .       # tipos: 0 errores
npm run lint                # ESLint: 0 errores
npm test                    # pruebas unitarias (node --test "tests/**/*.test.mjs")
npm run build               # build de producción (Next.js)

# Base de datos — desde la raíz, en Git Bash (requiere PostgreSQL 18 local)
bash database/scripts/probar_local.sh   # migraciones en BD temporal + pruebas_reglas.sql + concurrencia de consecutivos

# Frontend — desde NOVA_FT/ (no tiene tests ni linter)
npm run typecheck           # línea base: 28 errores, todos en código original de NOVA; no agregar nuevos
npx vite build              # build (npm run build corre tsc primero y se detiene por la línea base de NOVA)
```

Solo se corre lo de la parte que se tocó. Si `npx` falla por los espacios de la ruta: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json` y `node node_modules/vite/bin/vite.js build`.

Resultado esperado: todo sin errores (frontend: sin errores nuevos sobre la línea base). Sin ejecución real no hay verificación.

## Verificación adicional

- Revisar manualmente la ruta o pantalla modificada con `npm run dev` del backend (http://localhost:3000) y del frontend (http://localhost:5173); o las configuraciones `sgd-backend` y `nova-frontend` de `.claude/launch.json`.
- Sin errores en la consola del navegador / en el log del dispositivo.
- Web: probar en un ancho de móvil (~375 px) y en desktop.
- Móvil: probar en emulador o dispositivo <!-- COMPLETAR: cuáles -->.
- UI nueva o rediseñada: checklist mínimo de `ux-heuristicas` (H1, H3, H5, H9).

## Estrategia objetivo

- **Unitario**: funciones puras, helpers y reglas de negocio.
- **Componente**: render y comportamiento de componentes.
- **Integración**: flujos de navegación y llamadas a servicios (con mocks).
- **E2E**: flujos críticos (Playwright en web; Detox/Maestro en móvil).
- **Usabilidad**: pruebas con usuarios y métricas de `ux-heuristicas/references/metricas-usabilidad.md`.

## Cobertura esperada

Meta del F-02 (RNF-AC-09): **≥ 60 %** en consecutivos, estados y permisos. Recomendado: reglas RN-AC-* críticas al 100 %.

## Pruebas obligatorias del módulo Archivo Central

Casos de la matriz de trazabilidad (`ia_contexto/spec/trazabilidad.md`); una tarea no se cierra sin su caso en verde. Los más críticos:

| Área | Caso | Regla |
|---|---|---|
| Consecutivos | N inserciones concurrentes → números únicos y secuenciales por tipo; reinicio al cambiar de año. | RN-AC-08 |
| Estados | Solo transiciones válidas de `business-rules.md`; enviar respuesta fallido no cierra. | RN-AC-09 |
| Permisos | Dependencia no ve otra dependencia; RA no ve retirados/graduados; intento denegado queda auditado. | RF-AC-023 |
| Duplicados | Mismo archivo en el mismo expediente → rechazado. | RN-AC-11 |
| Correo | Mismo Message-ID leído dos veces → una sola comunicación; respuesta sin etiqueta → se asocia por In-Reply-To. | RNF-AC-04 |
| Idempotencia | Importar el mismo Excel histórico dos veces → sin duplicados. | RF-AC-019 |
| Transferencias | En 2026, transferencia del año 2025 → bloqueada. | RN-AC-03 |
| Anulación | Anular → el registro sigue en la BD. | RN-AC-12 |
| IA | Sugerencia nunca cambia la clasificación sin confirmación. | RN-AC-13 |

RNF a medir (SGD-070): búsqueda < 3 s con 50.000 docs; correo visible ≤ 5 min; restauración de respaldo probada; carga + clasificación < 3 min con usuario real.

Datos de prueba: **siempre ficticios** (Ley 1581).
