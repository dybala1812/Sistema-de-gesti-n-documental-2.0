---
name: desarrollo
description: Convenciones de código, stack y criterio de commits de EDUCALC XE. Úsala antes de escribir o revisar código en este repo.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Desarrollo — EDUCALC XE

## Stack

- **Framework**: React 19 + Vite 8
- **Lenguaje**: JavaScript (JSX). TypeScript aún no está adoptado.
- **Routing**: React Router DOM 7
- **Estilos**: CSS personalizado con variables en `vite-project/src/index.css`. Tailwind CSS no está configurado formalmente.
- **Matemáticas / gráficas**: function-plot, KaTeX, MathJS
- **Iconos**: react-icons
- **Bundler**: Vite
- **Linter**: ESLint 10 con `@eslint/js`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`
- **Compilador**: React Compiler habilitado en `vite.config.js`

## Scripts disponibles

Trabaja siempre dentro de `vite-project/`:

```bash
npm run dev      # servidor de desarrollo
npm run build    # build de producción
npm run lint     # ESLint
npm run preview  # preview del build
```

## Estructura de carpetas

```text
vite-project/
  src/
    components/      # componentes React organizados por feature
    index.css        # variables globales y utilidades CSS
    main.jsx         # punto de entrada
    App.jsx          # raíz y rutas
  public/            # assets estáticos
```

> Nota: la estructura interna de `src/components/` aún debe ser estandarizada. No muevas archivos existentes sin una tarea explícita.

## Convenciones

- Componentes en PascalCase (`Laboratorio.jsx`).
- Archivos JSX para componentes; JS para utilidades.
- Usa las variables CSS definidas en `:root` (colores, tipografía, radios, sombras) antes de inventar nuevos valores.
- Mantén los estilos específicos de un componente en un archivo `.css` junto al componente cuando sea razonable.
- Evita incluir secrets directamente en el código fuente; usa variables de entorno `VITE_*` consciente de que se exponen en el bundle.

## Patrones permitidos

- Hooks de React y custom hooks.
- React Router en modo history (`BrowserRouter` implícito en Vercel mediante rewrites).
- Renderizado de fórmulas con KaTeX.
- Gráficas con function-plot.

## Patrones prohibidos

- No usar `eval()` ni `new Function()` para expresiones matemáticas del usuario; usar MathJS o un parser seguro.
- No almacenar secrets en el repositorio.
- No modificar `vercel.json` sin justificar el impacto en rutas y headers de seguridad.

## Criterio de commits

- Mensajes en español o inglés, consistentes con el historial existente.
- Formato sugerido: `<tipo>: <descripción corta>`
  - `feat:` nueva funcionalidad
  - `fix:` corrección
  - `refactor:` cambio interno sin cambio de comportamiento
  - `docs:` documentación
  - `test:` tests
  - `chore:` tareas de mantenimiento
- No incluir archivos de `node_modules/`, `dist/` ni archivos de entorno.

## Antes de entregar

- [ ] `npm run lint` pasa sin errores.
- [ ] `npm run build` genera el `dist/` sin fallos.
- [ ] No se agregan dependencias sin justificar.
- [ ] Si se toca CSS, se verifica visualmente en desktop y mobile.
