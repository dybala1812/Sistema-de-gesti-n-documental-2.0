---
name: desarrollo
description: Convenciones de código, stack, estructura y criterio de commits de Sistema de Gestión Documental (SGD). Úsala antes de escribir o revisar código en este repo.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Desarrollo — Sistema de Gestión Documental (SGD)

## Stack

| Parte | Carpeta | Tecnología |
|---|---|---|
| Frontend | `NOVA_FT/` (repo Git aparte, rama `desarrollo-archivo-central`) | React 18.3 + TypeScript + Vite 6 + Tailwind v4 + shadcn/ui (Radix) + React Router 7; alertas con Sileo; Excel con `xlsx` |
| Backend | `backned_sistema_gestion_documental/` | Next.js 16 (solo rutas `app/api`) + TypeScript 5 + `@supabase/supabase-js` con service role (solo en el servidor); ESLint 9 (`eslint-config-next`) |
| Base de datos | `database/supabase/` | Supabase PostgreSQL: migraciones SQL, funciones `fn_*` y `n8n_*`, RLS y triggers de auditoría |
| Automatización | n8n (F1–F6) | Solo la Bandeja de comunicaciones; habla únicamente con el backend (`POST /api/n8n/*`) |

## Scripts

Desarrollo: `npm run dev` del backend (http://localhost:3000) y del frontend (http://localhost:5173); o las configuraciones `sgd-backend` y `nova-frontend` de `.claude/launch.json`.

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

## Estructura de carpetas

```
Sistema de Gestion Documental/
├── NOVA_FT/                            # frontend de NOVA (repo aparte); lo nuestro:
│   └── src/app/
│       ├── pages/archivo-central/      # pantallas del módulo (un componente por pantalla)
│       ├── pages/comunicaciones/       # bandeja de comunicaciones
│       ├── lib/sgdApi.ts               # fetch al backend SGD: token y contrato de errores
│       └── lib/*Api.ts, services/      # clientes por recurso (catálogos, documentos, comunicaciones…)
├── backned_sistema_gestion_documental/
│   ├── app/api/<recurso>/route.ts      # rutas REST; app/api/n8n/ = APIs que llama n8n
│   ├── lib/                            # auth, errors, catalogos, comunicaciones, archivos, n8n
│   ├── tests/                          # pruebas unitarias (node --test)
│   └── archivos_sgd/                   # archivos subidos, locales e ignorados por Git
├── database/
│   ├── supabase/migrations/            # migraciones SQL, en orden por fecha
│   ├── supabase/tests/pruebas_reglas.sql
│   └── scripts/                        # probar_local.sh, verificar_supabase.mjs
├── flujos n8n/                         # flujos exportados en JSON
└── ia_contexto/                        # spec, tablero, historial
```

> No muevas archivos existentes sin una tarea explícita.

## Convenciones

- Componentes en PascalCase; utilidades y hooks en camelCase.
- Usar los tokens de `NOVA_FT/src/styles/theme.css` antes de inventar valores.
- Colores: respetar la paleta institucional de `frontend/color-palette.md` (primario `navy` `#1e3a5f`, acción `orange` `#e8740e`, acento `gold` `#c89b14`, fondos `beige`/`beigeAlt`). No hardcodear colores si existe token equivalente.
- Secretos solo en variables de entorno; recordar que las variables públicas del cliente (`VITE_*`, `NEXT_PUBLIC_*`, `EXPO_PUBLIC_*`) quedan expuestas en el bundle.
- Nombres, comentarios y mensajes en español.
- Errores del backend con el contrato RN-AC-15 (`lib/errors.ts`): `errorFormulario` (4xx, descripción y `campo`) o `errorSistema` (5xx, número del catálogo y motivo). Nunca `{ mensaje }` ni el texto crudo de PostgreSQL.
- El frontend llama al backend SGD por `lib/sgdApi.ts` (token, reintento de sesión y mensajes de error); no hace `fetch` propio.
- Las escrituras pasan por funciones SQL que reciben `p_usuario_id`, revisan el permiso con `fn_tiene_permiso` y auditan también los intentos denegados.

## Reglas de dominio (módulo Archivo Central)

Antes de implementar, leer el RF en `ia_contexto/spec/requirements.md`, las reglas en `ia_contexto/spec/business-rules.md` y las preguntas abiertas en `ia_contexto/spec/decisiones.md` (lo que está abierto **no se implementa por suposición**).

- Organización: Dependencia → Año → Asunto; un documento, un asunto; asuntos por dependencia, cada uno con código TRD.
- Consecutivos `ENT|SAL|INT-AAAA-NNNNNN` solo desde la función atómica de la BD (nunca en cliente ni en n8n).
- Estados de comunicación y transiciones: solo las de `business-rules.md`, centralizadas en un único servicio/función.
- Sin borrado físico: inactivar catálogos con uso; anular documentos/comunicaciones/lotes con motivo.
- Auditoría en toda acción relevante (usuario, acción, recurso, fecha, valores previos y nuevos), incluidos intentos denegados.
- Archivos guardados localmente en carpetas; en BD cada archivo tiene un id (tabla `archivo`) que lo referencia. Los registros usan `archivo_id`, nunca la ruta directamente. Sin binarios en la BD.
- Procesos masivos (lotes, FUID, histórico, historias) idempotentes y tolerantes a fallos por elemento.
- IA: solo sugerencia, confirmación humana, nunca en historias académicas.
- Parámetros (años mínimos, tamaño máx., plazos, recordatorios, umbral IA) leídos de la tabla de parámetros, no hardcodeados.
- Flujos n8n exportados en JSON al repo y documentados.

## Patrones permitidos

- Reglas de negocio y escrituras atómicas en funciones SQL; el backend valida la entrada y traduce los errores.
- Alertas de estado con Sileo, una a la vez (`lib/alertasCarga.ts`); el Toaster va por portal al `body`.
- Filas y tarjetas clicables con `tabIndex`, Enter/Espacio y `stopPropagation` en los botones internos.

## Patrones prohibidos

- No usar `eval()` ni `new Function()` con datos del usuario.
- No guardar secretos en el repositorio.
- No generar consecutivos fuera de la función de la BD.
- No hacer `DELETE` físico: inactivar o anular con motivo.
- No devolver al cliente rutas de archivos ni detalles internos de PostgreSQL.
- No escribir datos personales en logs ni en URLs (Ley 1581).
- No usar la service role key de Supabase en el frontend.

## Criterio de commits

Ver la skill `git` (ramas, formato `<tipo>(<módulo>): <descripción> (SGD-XXX)` y mensajes prohibidos).

## Antes de entregar

- [ ] Backend: `npx tsc --noEmit -p .`, `npm run lint` y `npm test` sin errores.
- [ ] Base de datos (si se tocó una migración o función): `bash database/scripts/probar_local.sh` termina en "Todo correcto".
- [ ] Frontend: `npm run typecheck` sin errores nuevos (línea base 28) y `npx vite build` termina.
- [ ] No se agregaron dependencias sin justificar.
- [ ] Si se tocó UI: verificación visual en desktop y móvil + checklist mínimo de `ux-heuristicas`.
