# Motion System — Sistema de Gestión Documental (SGD)

Plantilla de sistema de movimiento. `project-setup` reemplaza los `{{...}}`; si el proyecto no usa Tailwind, usa solo la parte de CSS puro.

## Criterio

- Movimiento funcional: confirmar una seleccion, abrir formularios u overlays, mostrar los pasos de un wizard, enfocar acciones importantes. Nada decorativo que distraiga de la tarea.
- Duraciones base: `160ms` para presionar/hover, `240ms` para overlays, `300ms` para entrada de contenido.
- Easing recomendado: `cubic-bezier(.2,.8,.2,1)` (entrada suave, sin rebote).
- Tono de movimiento del proyecto: {{TONO_MOVIMIENTO}} (ej. "sobrio y profesional", "jugueton", "app nativa premium").
- Respetar siempre `prefers-reduced-motion` (`motion-safe:` en Tailwind y fallback global en CSS).
- En mobile, ninguna animacion debe mover la barra inferior, cortar botones ni bloquear el uso con una mano.

## Tokens (Tailwind v4, dentro del `@theme` de `NOVA_FT/src/styles/theme.css`)

```css
@theme {
  --ease-brand: cubic-bezier(.2, .8, .2, 1);
  --ease-press: cubic-bezier(.4, 0, .2, 1);

  --animate-fade-in: fadeIn 200ms var(--ease-brand);
  --animate-slide-down: slideDown 300ms var(--ease-brand);
  --animate-slide-up: slideUp 260ms var(--ease-brand);
  --animate-modal: modalIn 300ms var(--ease-brand);
  --animate-toast: toastIn 300ms var(--ease-brand);
  --animate-progress: progressIn 700ms var(--ease-brand);
}

@keyframes fadeIn    { from { opacity: 0; } to { opacity: 1; } }
@keyframes slideDown { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: none; } }
@keyframes slideUp   { from { opacity: 0; transform: translateY(14px); }  to { opacity: 1; transform: none; } }
@keyframes toastIn   { from { opacity: 0; transform: translateY(-20px); } to { opacity: 1; transform: none; } }
@keyframes modalIn   { from { opacity: 0; transform: translateY(-20px) scale(.95); } to { opacity: 1; transform: none; } }
@keyframes progressIn { from { transform: scaleX(.08); opacity: .55; } to { transform: scaleX(1); opacity: 1; } }
```

## Utilidades

```css
@utility pressable {
  transition-property: transform, opacity, border-color, background-color, color, box-shadow;
  transition-duration: 160ms;
  transition-timing-function: var(--ease-press);
}
.pressable:active { opacity: .82; transform: scale(.98); }

@utility card-hover {
  transition-property: transform, border-color, box-shadow;
  transition-duration: 220ms;
  transition-timing-function: var(--ease-brand);
}
@media (hover: hover) {
  .card-hover:hover {
    transform: translateY(-2px);
    border-color: color-mix(in srgb, var(--secondary) 55%, transparent);
    box-shadow: 0 16px 44px rgba(0, 0, 0, .18);
  }
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: .01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: .01ms !important;
  }
}
```

## Ejemplos de uso

```tsx
// Tarjetas con entrada escalonada
{items.map((item, i) => (
  <button key={item.id} type="button"
    className="card card-hover pressable motion-safe:animate-slide-up"
    style={{ animationDelay: `${i * 70}ms` }}>
    {item.title}
  </button>
))}

// Modal
<div className="overlay motion-safe:animate-fade-in">
  <div className="modal motion-safe:animate-modal">...</div>
</div>

// Notificacion
<div role="status" className="toast motion-safe:animate-toast">Guardado correctamente</div>
```

## Checklist antes de animar

- La animacion comunica una accion o un cambio de estado (heuristica H1 de `ux-heuristicas`).
- No bloquea la lectura, la captura de datos ni la navegacion.
- Usa `motion-safe:` si el movimiento no es indispensable.
- El color de acento es un detalle, no decoracion excesiva.
