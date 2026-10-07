# Instrucciones de Frontend

## Stack

- React 19 con Vite.
- JavaScript ESM.
- React Router para navegacion.
- CSS global en `src/index.css` y estilos inline en componentes existentes.
- `mathjs`, `katex` y `function-plot` para experiencia matematica.

## Reglas generales

- Mantener componentes de pagina en `vite-project/src/pages/`.
- Mantener componentes reutilizables en `vite-project/src/components/`.
- Mantener datos academicos en `vite-project/src/data/`.
- Evitar dependencias nuevas si una solucion simple encaja con el stack actual.
- Respetar variables globales de `src/index.css` antes de crear nuevos colores o sombras.
- No introducir Tailwind hasta que el proyecto decida una migracion o convivencia formal.

## Componentes

- Usar nombres claros y orientados al dominio educativo.
- Mantener los componentes de UI enfocados en una responsabilidad.
- Si un componente mezcla UI, calculo y renderizado complejo, extraer helpers progresivamente.
- Para graficacion, favorecer helpers en `src/components/graficos/` y considerar `function-plot` cuando haya ejes, zoom o multiples curvas.
- Las tarjetas de unidades del curso deben mostrar el logo/icono animado correspondiente. Si el id viene en plural (`limites`, `derivadas`, `aplicaciones`), normalizarlo antes de renderizar animaciones.
- En paginas de tema, el sidebar debe funcionar como menu de recursos con scroll suave hacia secciones internas: contenido, videos, laboratorio y saberes previos.

## Contenido visible

- Usar espanol claro, universitario y cercano.
- Corregir textos con codificacion corrupta antes de ampliar una seccion.
- Evitar texto excesivamente tecnico si el usuario objetivo es estudiante de Calculo I.
- Mantener CTA y labels accionables: "Explorar", "Resolver", "Graficar", "Ver resolucion".

## IA en frontend

- Recordar que `VITE_OPENAI_API_KEY` en frontend es solo aceptable para demo/local.
- No agregar flujos que expongan secretos reales en produccion.
- Mantener mensajes de error didacticos y utiles.
- La IA no debe dominar el laboratorio visual. Debe quedar como ayuda secundaria o accion discreta despues de resolver.

## Validacion

Antes de cerrar cambios de frontend:

```powershell
cd vite-project
npm run lint
npm run build
```

Para cambios visuales, revisar manualmente desktop y mobile.
