# Responsive y Accesibilidad

## Responsive

- Base mobile-first cuando se creen estilos nuevos.
- Usar el contenedor global `.container` con max-width `1200px`.
- En desktop, grids de 2 a 4 columnas segun contenido.
- En tablet y mobile, colapsar a una columna si el contenido requiere lectura.
- Evitar que botones, badges o cards dependan de texto en una sola linea.
- Las zonas de graficacion deben tener alto minimo estable para evitar saltos de layout.

## Breakpoints actuales

El CSS global ya usa:

- `1024px`: reduce grids grandes.
- `768px`: secciones mas compactas, grids a una columna, titulos mas pequenos.

Mantener estos cortes salvo que una vista necesite un ajuste especifico.

## Accesibilidad

- Todo input debe tener label visible o asociacion clara.
- Todo boton con icono debe tener texto visible o `aria-label`.
- Mantener foco visible en controles interactivos.
- Imagenes informativas deben tener `alt` descriptivo.
- Imagenes decorativas pueden usar `alt=""`.
- No depender solo del color para explicar estados matematicos: acompanar con texto, icono o etiqueta.
- Respetar `prefers-reduced-motion` si se agregan animaciones.

## Graficas

- Incluir resumen textual del resultado debajo o al lado de la grafica.
- Usar colores con significado consistente:
  - azul para funcion principal;
  - amarillo para limite o punto de atencion;
  - rojo para tangente, error o punto critico segun contexto;
  - verde para crecimiento, exito o solucion valida.
- Las etiquetas numericas deben ser legibles en mobile.
- Si hay zoom en la grafica, ofrecer controles visibles `+` y `-`, no solo gestos del mouse.
- Si se muestran aproximaciones por lados, acompanarlas con leyenda textual.

## Formularios matematicos

- Placeholders utiles: `x^2`, `(x^2 - 4)/(x - 2)`, `sin(x)`.
- Mensajes de error deben sugerir una accion concreta.
- No borrar automaticamente la entrada del estudiante ante error.
