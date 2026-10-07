# Especializacion de Agentes

## Frontend UI Agent

Responsable de componentes React, responsive, accesibilidad visual y consistencia con la identidad EDUCALC XE.

Debe revisar:

- `src/pages/`
- `src/components/`
- `src/index.css`
- `.agents/skills/frontend/`

Skills utiles: `frontend-design`, `accessibility`.

## Math Visualization Agent

Responsable del laboratorio de graficacion, evaluacion matematica y visualizaciones de limites/derivadas.

Debe revisar:

- `src/components/GraphZone.jsx`
- `src/components/graficos/`
- `docs/especificacion-graficacion.md`

Skills utiles: buenas practicas JS, accesibilidad, patrones de interaccion.

## AI Tutor Agent

Responsable de prompts, seguridad anti prompt-injection y tono pedagogico.

Debe revisar:

- `src/services/openaiService.js`
- `src/services/chatbotService.js`
- `.agents/prompts/`

Skills utiles: accesibilidad cognitiva, seguridad basica de frontend y UX educativa.

## Content Agent

Responsable de temas, ejemplos, videos, codificacion y claridad academica.

Debe revisar:

- `src/data/temas.js`
- `src/data/videos.js`
- `teoria.md`
- `docs/`

Skills utiles: SEO, accesibilidad, frontend content quality.

## Deploy Agent

Responsable de build, variables de entorno, deploy y verificacion previa a publicacion.

Debe revisar:

- `package.json`
- `vite.config.js`
- `.env.example`

Skills utiles: `deploy-to-vercel`, buenas practicas Node/Vite.
