# Tailwind CSS Animate

## Estado

Tailwind CSS y `tailwindcss-animate` no estan instalados actualmente en el proyecto.

## Recomendacion

No introducir Tailwind solo para animaciones mientras el proyecto usa CSS global e inline styles. Si mas adelante se migra a Tailwind, usar `tailwindcss-animate` para:

- entrada suave de paneles de chatbot;
- microinteracciones de tarjetas;
- estados de aparicion en resultados;
- transiciones de modales o drawers.

## Regla

Antes de agregar Tailwind:

1. Definir si se migra todo el sistema visual o si convivira con CSS actual.
2. Mapear variables actuales (`#0047CC`, `#F4B400`, radios, sombras, fuentes).
3. Evitar mezclar demasiados estilos inline con clases Tailwind en el mismo componente.
