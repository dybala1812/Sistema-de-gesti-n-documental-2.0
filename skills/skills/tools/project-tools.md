# Herramientas del Proyecto

## npm scripts

- `npm run dev`: inicia Vite.
- `npm run build`: compila produccion.
- `npm run lint`: ejecuta ESLint.
- `npm run preview`: sirve el build.

## Librerias clave

- `react`, `react-dom`, `react-router-dom`: UI y rutas.
- `mathjs`: evaluacion y derivadas.
- `katex`: formulas en respuestas IA.
- `function-plot`: graficacion matematica recomendada.

## Variables de entorno

- `VITE_OPENAI_API_KEY`: clave usada por el frontend para la demo IA.

## Nota de seguridad

No usar claves reales de OpenAI en frontend para produccion. Crear un backend proxy antes de despliegue real.
