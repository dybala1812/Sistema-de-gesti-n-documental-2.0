# Memoria del Proyecto

## Estado actual

- Proyecto React/Vite dentro de `vite-project/`.
- Plataforma educativa de Calculo I llamada EDUCALC XE.
- Contenido academico en `src/data/temas.js`.
- Biblioteca multimedia en `src/data/videos.js`.
- Chatbot y resolucion IA en `src/services/`.
- Laboratorio grafico principal en `src/components/GraphZone.jsx`.

## Decisiones tomadas

- Mantener skills relevantes para frontend educativo: accesibilidad, frontend design, SEO, buenas practicas Node/Vite, deploy Vercel y Tailwind solo como referencia futura.
- No priorizar Astro ni TypeScript avanzado porque no corresponden al stack actual.
- Registrar Tailwind/Tailwind animate como opcion futura, no como dependencia activa.

## Riesgos conocidos

- Hay textos con codificacion corrupta en varios archivos visibles.
- La key de OpenAI se lee desde el cliente.
- Existen prompts duplicados entre `openaiService.js` y `chatbotService.js`.
- `GraphZone.jsx` concentra demasiada logica de estado, UI, calculo y dibujo.
- `function-plot` esta documentado como recomendado, pero no domina la implementacion actual.

## Proximos candidatos de mejora

- Normalizar codificacion UTF-8 de textos.
- Extraer prompts IA a un modulo compartido.
- Refactorizar graficacion hacia helpers o `function-plot`.
- Agregar pruebas basicas para parsing de YouTube y validacion de inputs matematicos.
