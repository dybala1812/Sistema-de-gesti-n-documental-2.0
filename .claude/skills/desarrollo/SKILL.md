---
name: desarrollo
description: Convenciones de código, stack, estructura y criterio de commits de Sistema de Gestión Documental (SGD). Úsala antes de escribir o revisar código en este repo.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Desarrollo — Sistema de Gestión Documental (SGD)

## Stack

React + TypeScript + Vite + Tailwind v4 + shadcn/ui (frontend NOVA_FT); Supabase PostgreSQL; n8n; backend por definir (ver ia_contexto/spec/decisiones.md P-11)

<!-- COMPLETAR: framework, lenguaje, routing/navegación, estilos, estado, librerías clave, linter, compilador/bundler (con versiones). -->

## Scripts

Trabajar siempre dentro de `{{DIR_APP}}`:

```bash
{{CMD_DEV}}     # desarrollo
{{CMD_BUILD}}   # build de producción
{{CMD_LINT}}    # lint
{{CMD_TEST}}    # tests
```

## Estructura de carpetas

<!-- COMPLETAR: árbol real con una línea de propósito por carpeta. -->

> No muevas archivos existentes sin una tarea explícita.

## Convenciones

- Componentes en PascalCase; utilidades y hooks en camelCase.
- Usar los tokens de `NOVA_FT/src/styles/theme.css` antes de inventar valores.
- Colores: respetar la paleta institucional de `frontend/color-palette.md` (primario `navy` `#1e3a5f`, acción `orange` `#e8740e`, acento `gold` `#c89b14`, fondos `beige`/`beigeAlt`). No hardcodear colores si existe token equivalente.
- Secretos solo en variables de entorno; recordar que las variables públicas del cliente (`VITE_*`, `NEXT_PUBLIC_*`, `EXPO_PUBLIC_*`) quedan expuestas en el bundle.
<!-- COMPLETAR: convenciones propias detectadas en el código. -->

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

<!-- COMPLETAR -->

## Patrones prohibidos

- No usar `eval()` ni `new Function()` con datos del usuario.
- No guardar secretos en el repositorio.
<!-- COMPLETAR: prohibiciones propias del proyecto. -->

## Criterio de commits

Ver la skill `git` (ramas, formato `<tipo>(<módulo>): <descripción> (SGD-XXX)` y mensajes prohibidos).

## Antes de entregar

- [ ] `{{CMD_LINT}}` pasa sin errores.
- [ ] `{{CMD_TEST}}` pasa (o está documentado por qué no aplica).
- [ ] `{{CMD_BUILD}}` termina correctamente.
- [ ] No se agregaron dependencias sin justificar.
- [ ] Si se tocó UI: verificación visual en desktop y móvil + checklist mínimo de `ux-heuristicas`.
