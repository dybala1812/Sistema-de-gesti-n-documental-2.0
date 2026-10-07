# Responsive, Móvil y Accesibilidad — {{PROYECTO}}

Plataforma: {{PLATAFORMA}}.

## Responsive (web)

- Mobile-first en los estilos nuevos.
- Breakpoints: <!-- COMPLETAR: los reales del proyecto (ej. Tailwind sm 640 / md 768 / lg 1024 / xl 1280) -->.
- Colapsar a una columna cuando el contenido es de lectura.
- Ningún botón, badge o card depende de que el texto quepa en una sola línea.
- Altos mínimos estables en zonas que cargan contenido (evitar saltos de layout).

## Móvil (si aplica)

- Objetivos táctiles ≥ 44×44 pt (iOS) / 48×48 dp (Android), separados entre sí.
- Respetar las safe areas (notch, barra de gestos).
- Teclado adecuado por campo (`inputMode`/`keyboardType`) y que el teclado no tape el campo activo.
- El botón atrás de Android y el swipe-back de iOS funcionan como se espera.
- Todo gesto tiene una alternativa visible.
- Estado sin conexión y reintento visibles.
- Probar en al menos un dispositivo pequeño (~360 px de ancho) y uno grande.

## Accesibilidad

- Todo input tiene label visible o asociado (no solo placeholder).
- Los botones de solo icono tienen `aria-label` / `accessibilityLabel`.
- Foco visible en todos los controles; orden de tabulación lógico.
- `alt` descriptivo en imágenes informativas; `alt=""` en las decorativas.
- No depender solo del color.
- Respetar `prefers-reduced-motion` y el tamaño de fuente del sistema.
- Compatible con lector de pantalla (VoiceOver/TalkBack en móvil).

## Formularios

- Placeholders como ejemplo, no como etiqueta.
- Validación en línea con un mensaje que diga cómo corregir (H5, H9).
- Nunca borrar automáticamente lo que el usuario escribió ante un error.
