# Contexto del Proyecto

## Producto

EDUCALC XE es una plataforma educativa universitaria para Calculo I. El foco actual es ayudar a estudiantes a entender limites, continuidad, derivadas y aplicaciones de la derivada mediante contenido guiado, videos, graficacion interactiva y asistencia IA paso a paso.

## Stack actual

- React 19 con Vite.
- JavaScript con modulos ESM.
- React Router para rutas.
- `mathjs` para evaluacion numerica y derivacion simbolica.
- `katex` para renderizar formulas en respuestas IA.
- `function-plot` esta instalado y documentado como camino recomendado, aunque parte de la grafica actual usa SVG manual.
- ESLint disponible con `npm run lint`.

## Ubicacion principal

El proyecto de aplicacion vive en `vite-project/`. La raiz del repositorio contiene esta carpeta `.agents` y el `skills-lock.json`.

## Rutas de la app

- `/`: pagina de inicio.
- `/saberes-previos`: contenidos base.
- `/calculo1`: vista general del curso.
- `/calculo1/:unidadId`: listado de temas por unidad.
- `/calculo1/:unidadId/:temaId`: pagina de tema.
- `/biblioteca`: biblioteca multimedia.

## Dominio educativo

Las unidades centrales son:

- Limites y continuidad: 9 temas.
- Derivadas: 10 temas.
- Aplicaciones de la derivada: 12 temas.

El tono pedagogico debe ser claro, paciente, universitario y amable. La app busca reducir ansiedad matematica, no solo mostrar resultados.

## Identidad visual

- Marca: EDUCALC XE.
- Enfoque: EdTech universitaria moderna.
- Paleta: azul `#0047CC`, amarillo `#F4B400`, blanco, grises claros y texto oscuro.
- Fuentes declaradas: Poppins para titulos, Inter para cuerpo.
- Estilo: limpio, profesional, confiable, con imagenes reales de estudiantes y apoyo institucional.
- Guia frontend detallada: `../frontend/`.

## Activos

Los assets publicos estan en `vite-project/public/` e incluyen logos universitarios, imagenes de estudiantes y recursos visuales academicos.
