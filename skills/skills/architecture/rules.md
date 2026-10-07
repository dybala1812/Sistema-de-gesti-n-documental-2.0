# Reglas de Arquitectura

## Principios

- Mantener la aplicacion como frontend React/Vite mientras no exista una necesidad real de backend.
- Centralizar contenido academico estructurado en `src/data/`.
- Mantener los componentes de pagina en `src/pages/` y componentes reutilizables en `src/components/`.
- Separar logica compleja de graficacion en `src/components/graficos/`.
- Evitar duplicar prompts IA entre servicios; si crecen, moverlos a un modulo compartido.
- Si una regla, patron o instruccion se vuelve repetitiva, actualizar la documentacion correspondiente en `.agents/skills/` para convertirla en memoria reutilizable del proyecto.

## Graficacion

- Usar `mathjs` para evaluar expresiones, calcular derivadas y validar funciones.
- Preferir `function-plot` para ejes, zoom, curvas, grid e interaccion cuando se amplie el laboratorio.
- Si se mantiene SVG manual, aislar helpers de escala, muestreo, ejes y paths para no inflar `GraphZone.jsx`.
- Tratar discontinuidades, asintotas y limites laterales como casos de dominio, no como errores genericos.

## IA y seguridad

- La key `VITE_OPENAI_API_KEY` esta expuesta al navegador; solo es aceptable para demo educativa local.
- Para produccion, crear backend proxy antes de publicar resolucion IA con claves reales.
- Mantener validacion contra prompt injection y restringir respuestas a Calculo I.
- Respuestas IA deben ser paso a paso, con LaTeX simple y sin saltar razonamiento pedagogico.

## UI

- Respetar la paleta global de `src/index.css`.
- Seguir las instrucciones de frontend en `.agents/skills/frontend/`.
- Cuidar accesibilidad: contraste, labels, foco visible, alt text y navegacion por teclado.
- No introducir Tailwind hasta decidir migracion o convivencia clara con los estilos actuales.
- Corregir textos con problemas de codificacion antes de ampliar contenido visible.

## Calidad

- Ejecutar `npm run lint` antes de cerrar cambios de codigo.
- Ejecutar `npm run build` para validar integracion cuando se toquen rutas, Vite, imports o dependencias.
- Revisar manualmente las paginas principales tras cambios visuales.
- Cuando una tarea revele una decision permanente, agregarla a `memory/` o al area de skills que corresponda.
