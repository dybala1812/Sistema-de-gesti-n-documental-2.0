# Sistema de Diseño — Sistema de Gestión Documental (SGD)

## Dirección visual

Estilo: **institucional sobrio: confiable, ordenado, legible, cálido (fondos beige, autoridad navy)**.

<!-- COMPLETAR: 3–5 adjetivos de cómo debe sentirse la app y referencias visuales. Si no hay marca definida, proponer una con la skill frontend-design y registrar la decisión en memory/. -->

## Layout

<!-- COMPLETAR según la plataforma; borrar lo que no aplique. -->

### Web
- Navbar: marca a la izquierda, navegación clara, estado activo visible (H1).
- Contenedor con ancho máximo consistente.
- Secciones con una idea o acción principal cada una (H8).

### Móvil
- Navegación por tab bar o stack según la plataforma; respetar las safe areas.
- Una acción principal por pantalla, al alcance del pulgar.
- Bottom sheets y modales siempre con forma visible de cerrarlos (H3).

### Cards / listas
- Fondo, borde, radio y sombra desde los tokens.
- Hover (web) o pressed state (móvil) sutil.

## Tipografía

- Títulos: por definir (fonts.css vacío).
- Texto: por definir (fonts.css vacío).
- Jerarquía clara: no usar bloques largos sin subtítulos ni listas.

## Interacciones

- Transiciones de 160–300 ms (ver `tailwind-css-patterns/references/motion-system.md` o `animation-creator`).
- El resultado de una acción aparece cerca de la acción que lo genera.
- Las acciones destructivas piden confirmación y ofrecen deshacer cuando sea posible (H3, H5).

## Evitar

- Estéticas genéricas ajenas a la marca.
- Decoración que no comunica (H8).
- Animaciones que distraen de la tarea.
