---
name: project-setup
description: Adapta este kit de skills por defecto a un proyecto nuevo. Detecta el stack del repo, pregunta lo que falta (producto, marca, plataforma web/móvil) y reemplaza todos los {{PLACEHOLDERS}} de .agents/skills/. Úsala cuando el kit se acaba de copiar a un repo, cuando digan "configura las skills", "adapta las skills a este proyecto" o "inicializa el proyecto", o si aún quedan {{...}} sin llenar.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Project Setup — adaptar el kit a un proyecto nuevo

Este kit es **genérico**: no trae nada de proyectos anteriores. Las partes que dependen del proyecto están marcadas con `{{VARIABLE}}` o con bloques `<!-- COMPLETAR: ... -->`. Esta skill los llena con datos reales.

## Regla de oro

**Nunca inventes datos.** Lo que se pueda detectar en el repo se detecta. Lo que no, se pregunta. Lo que el usuario aún no sabe se deja como `<!-- PENDIENTE: ... -->` y se crea una tarea de seguimiento; no se rellena con supuestos.

## Paso 0 — Ubicar el kit

- El kit debe vivir en `<repo>/.agents/skills/`. Si está en otra ruta, propón moverlo antes de seguir.
- Lista los pendientes: `grep -rn "{{" .agents/skills --include=*.md | grep -v project-setup`

## Paso 1 — Detectar el stack (sin preguntar)

Revisa lo que exista:

| Archivo | Indica |
|---|---|
| `package.json` | framework (react, next, vue, svelte, astro, expo, react-native, ionic, capacitor), scripts `dev/build/lint/test`, TypeScript, Tailwind, librería de tests |
| `pubspec.yaml` | Flutter (`flutter run`, `flutter test`, `flutter analyze`) |
| `android/`, `ios/`, `app.json`/`app.config.*` | App móvil nativa / Expo |
| `tsconfig.json` | TypeScript |
| `tailwind.config.*` o `@import "tailwindcss"` / `@theme` en el CSS | Tailwind (v3 o v4) |
| `vite.config.*`, `next.config.*`, `angular.json` | Bundler / framework |
| `.eslintrc*`, `eslint.config.*`, `biome.json`, `.prettierrc` | Linter / formateador |
| `vitest.config.*`, `jest.config.*`, `playwright.config.*`, `cypress/` | Testing |
| `vercel.json`, `netlify.toml`, `firebase.json`, `Dockerfile`, `eas.json` | Hosting / deploy |
| `.env.example` | Variables de entorno (sin leer `.env` reales) |
| CSS global (`src/index.css`, `globals.css`, `theme.*`) | Paleta y fuentes actuales |
| subcarpeta con su propio `package.json` | `{{DIR_APP}}` (la app no está en la raíz) |

Si el repo está vacío (proyecto que apenas empieza), salta al paso 2 y pregunta también el stack.

## Paso 2 — Preguntar lo que no se puede detectar

Haz las preguntas juntas, en un solo mensaje y con opciones cuando sea posible:

1. Nombre del proyecto y descripción en una frase.
2. Plataforma: web, móvil (iOS/Android) o ambas.
3. Usuarios principales y tono de comunicación (formal, cercano, pedagógico…).
4. Identidad visual: colores de marca (primario, acento), fuentes y estilo (corporativo, minimalista, oscuro premium, jugueton…). Si no hay marca, ofrece proponer una con `frontend-design`.
5. Prefijo de las tareas (ej. `INV`, `APP`).
6. Restricciones: "no usar X", librerías obligatorias, backend sí/no, datos sensibles.

## Paso 3 — Variables

| Variable | Fuente |
|---|---|
| `{{PROYECTO}}` | pregunta 1 |
| `{{DESCRIPCION_PRODUCTO}}` | pregunta 1 |
| `{{PLATAFORMA}}` | detección + pregunta 2 (`web`, `móvil`, `web + móvil`) |
| `{{USUARIOS}}` / `{{TONO}}` | pregunta 3 |
| `{{STACK}}` | detección (lista con versiones de `package.json`/`pubspec.yaml`) |
| `{{LENGUAJE}}` | detección |
| `{{DIR_APP}}` | detección (`.` si la app está en la raíz) |
| `{{CMD_DEV}}`, `{{CMD_BUILD}}`, `{{CMD_LINT}}`, `{{CMD_TEST}}` | scripts reales; si no existe el script escribe `no configurado` y crea una tarea |
| `{{RUTA_ESTILOS_GLOBALES}}` | detección |
| `{{COLOR_PRIMARIO}}`, `{{COLOR_ACENTO}}`, `{{COLOR_FONDO}}`, `{{COLOR_TEXTO}}` | CSS actual o pregunta 4 |
| `{{FUENTE_TITULOS}}`, `{{FUENTE_TEXTO}}` | CSS actual o pregunta 4 |
| `{{ESTILO_VISUAL}}`, `{{TONO_MOVIMIENTO}}` | pregunta 4 |
| `{{HOSTING}}` | detección |
| `{{PREFIJO_TAREAS}}` | pregunta 5 |

## Paso 4 — Llenar los archivos

1. Reemplaza las variables en todos los `.md` de `.agents/skills/` (excepto esta skill).
2. Completa los bloques `<!-- COMPLETAR -->` con contenido real, quita el comentario y deja el texto.
3. Ajusta según el stack:
   - **Sin Tailwind** → en `context/loaded-skills.md` marca `tailwind-css-patterns` como "referencia futura" y no la cargues por defecto.
   - **Sin TypeScript** → `typescript-advanced-types` queda "diferida".
   - **Móvil** → en `frontend/responsive-accessibility.md` y `ux-heuristicas` activa los ítems 📱; en `testing` agrega dispositivos/emuladores.
   - **Web** → los ítems 📱 aplican solo a la vista mobile responsive.
   - **Hay backend o API** → completa `seguridad` (autenticación, autorización, secretos del servidor) y `architecture/rules.md`.
4. Borra las secciones que no apliquen (no las dejes vacías). Una skill genérica estorba más de lo que ayuda.
5. Si existe `project-manager`, inicializa `ia_contexto/` siguiendo su sección "Preparar un proyecto nuevo".

## Paso 5 — Verificar

```bash
grep -rn "{{" .agents/skills --include=*.md | grep -v project-setup   # debe quedar vacío
grep -rn "COMPLETAR" .agents/skills --include=*.md                      # debe quedar vacío
grep -rn "PENDIENTE" .agents/skills --include=*.md                      # lo que falta: cada uno tiene su tarea
```

- Comprueba que los comandos documentados existen (abre los `scripts` de `package.json`; ejecuta `{{CMD_LINT}}` si es seguro).
- Entrega al usuario un resumen corto: qué se detectó, qué se preguntó, qué quedó pendiente.

## Paso 6 — Registrar

- Escribe en `memory/project-memory.md` la fecha y la línea "Kit de skills adaptado".
- Si existe `ia_contexto/historial.md`, registra la inicialización.

## Mantener el kit limpio

- El kit maestro (la copia por defecto) **no se edita desde un proyecto**. Las mejoras genéricas que surjan en un proyecto se copian a mano al kit maestro, sin datos del proyecto.
- Antes de llevar una mejora al kit, revisa que no contenga nombres, colores, rutas, claves ni dominio del proyecto.
