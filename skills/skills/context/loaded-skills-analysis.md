# Analisis de Skills Cargadas

Se encontraron skills existentes en `vite-project/.agents/skills/`.

## frontend-design

Estado: util para el proyecto.

Por que aporta:

- EDUCALC XE depende mucho de UI educativa, jerarquia visual y confianza academica.
- Ayuda a mejorar paginas, componentes, responsive y experiencia de aprendizaje.

Como aplicarla aqui:

- Mantener una estetica EdTech universitaria, no una landing generica.
- Priorizar claridad, legibilidad y motivacion del estudiante.
- Usar imagenes reales y recursos academicos ya disponibles en `public/`.

## tailwind-css-patterns

Estado: condicional.

Por que no se aplica directamente ahora:

- El proyecto no tiene Tailwind instalado.
- El sistema visual actual usa `src/index.css` y estilos inline en componentes.

Como podria servir despues:

- Si se migra a Tailwind, convertir variables actuales a theme tokens.
- Usar patrones mobile-first, grid, foco visible, responsive y animaciones respetando `prefers-reduced-motion`.
- Integrar `tailwindcss-animate` solo si se adopta Tailwind formalmente.

## typescript-advanced-types

Estado: diferida.

Por que no aplica ahora:

- El codigo actual esta en JavaScript.
- No hay `tsconfig`, `.tsx` ni flujo de tipos avanzado.

Cuando aplicarla:

- Si se migra el proyecto a TypeScript.
- Si se tipan unidades, temas, videos, resultados de graficacion y respuestas IA.
- Si se crea un cliente API o backend proxy con contratos tipados.

## Conclusion

Para el estado actual del proyecto, lo mas importante es conservar enfoque de frontend educativo, accesibilidad, SEO y buenas practicas Vite/React. Tailwind y TypeScript quedan como rutas de evolucion, no como reglas activas.
