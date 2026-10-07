---
name: desarrollo
description: Convenciones de código, stack, estructura y criterio de commits de {{PROYECTO}}. Úsala antes de escribir o revisar código en este repo.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Desarrollo — {{PROYECTO}}

## Stack

{{STACK}}

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
- Usar los tokens de `{{RUTA_ESTILOS_GLOBALES}}` antes de inventar valores.
- Secretos solo en variables de entorno; recordar que las variables públicas del cliente (`VITE_*`, `NEXT_PUBLIC_*`, `EXPO_PUBLIC_*`) quedan expuestas en el bundle.
<!-- COMPLETAR: convenciones propias detectadas en el código. -->

## Patrones permitidos

<!-- COMPLETAR -->

## Patrones prohibidos

- No usar `eval()` ni `new Function()` con datos del usuario.
- No guardar secretos en el repositorio.
<!-- COMPLETAR: prohibiciones propias del proyecto. -->

## Criterio de commits

Ver la skill `git` (ramas, formato `<tipo>(<módulo>): <descripción> ({{PREFIJO_TAREAS}}-XXX)` y mensajes prohibidos).

## Antes de entregar

- [ ] `{{CMD_LINT}}` pasa sin errores.
- [ ] `{{CMD_TEST}}` pasa (o está documentado por qué no aplica).
- [ ] `{{CMD_BUILD}}` termina correctamente.
- [ ] No se agregaron dependencias sin justificar.
- [ ] Si se tocó UI: verificación visual en desktop y móvil + checklist mínimo de `ux-heuristicas`.
