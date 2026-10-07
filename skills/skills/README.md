# Agents Skills Workspace

Esta carpeta guarda el contexto operativo para agentes IA que trabajen en EDUCALC XE. El orden actual usa `.agents/skills/` como base para documentar reglas, memoria, prompts, flujos y especializaciones del proyecto.

## Estructura

- `agents/`: especializacion sugerida de agentes por tipo de tarea.
- `architecture/`: reglas tecnicas y decisiones de arquitectura.
- `context/`: resumen del producto, stack, dominio academico y skills cargadas.
- `frontend/`: instrucciones del frontend, guia visual, diseno, responsive y paleta de colores.
- `memory/`: memoria viva del proyecto para futuras sesiones.
- `prompts/`: prompts reutilizables para tutor IA, resolucion paso a paso y revision de contenido.
- `tools/`: comandos y herramientas relevantes del proyecto.
- `workflows/`: flujos repetibles de trabajo para desarrollo, QA y contenido educativo.
- `frontend-design/`, `tailwind-css-patterns/`, `typescript-advanced-types/`: skills externas cargadas localmente.
- `tailwindcss-animate.md`: nota de estado para una posible adopcion futura.

## Proyecto

EDUCALC XE es una plataforma educativa universitaria para Calculo I hecha con React, Vite y JavaScript. El producto combina contenido academico, videos, graficacion interactiva y asistencia IA paso a paso para limites, continuidad, derivadas y aplicaciones de la derivada.

## Skills seleccionadas

Del lock propuesto se conservan como utiles: accesibilidad, frontend design, SEO, deploy a Vercel, buenas practicas Node/Vite y patrones Tailwind solo como referencia futura. Se descartan por ahora Astro, Astro framework, backend Node especializado y TypeScript avanzado porque el proyecto actual es React/Vite en JavaScript y no tiene backend propio ni TypeScript.

Las skills cargadas localmente se analizaron en `context/loaded-skills-analysis.md`.

## Prioridades para agentes

- Mantener claridad academica y tono pedagogico paciente.
- Respetar la identidad visual EdTech universitaria.
- Cuidar accesibilidad, contraste, responsive y legibilidad.
- No introducir Tailwind, TypeScript o backend sin una decision explicita del proyecto.
- Validar cambios de codigo con `npm run lint` y, si aplica, `npm run build` desde `vite-project/`.

## Mantenimiento de skills

Si una instruccion, decision, patron o correccion se repite mas de una vez, debe documentarse en la skill o archivo correspondiente dentro de `.agents/skills/`.

Regla practica:

- Instrucciones de frontend: actualizar `frontend/`.
- Reglas tecnicas: actualizar `architecture/`.
- Prompts reutilizables: actualizar `prompts/`.
- Flujos de trabajo: actualizar `workflows/`.
- Decisiones o aprendizajes del proyecto: actualizar `memory/`.
- Contexto general del producto: actualizar `context/`.

El objetivo es que las proximas sesiones no dependan de recordar conversaciones anteriores: las reglas importantes deben vivir en archivos.
