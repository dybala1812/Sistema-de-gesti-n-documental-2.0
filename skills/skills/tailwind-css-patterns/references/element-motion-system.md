# ELEMENT Motion System

Guia de animaciones para ELEMENT Cotizador. Mantiene el tono oscuro, premium y mobile-first del proyecto: movimientos cortos, precisos, con sensacion de app nativa y acento dorado `#b69462`.

## Criterio visual

- Usa movimiento funcional: confirmar seleccion, abrir formularios, revelar pasos del wizard, enfocar acciones importantes.
- Duraciones base: `160ms` para presion/hover, `240ms` para overlays, `300ms` para entradas de contenido.
- Easing recomendado: `cubic-bezier(.2,.8,.2,1)` para entradas suaves sin rebote exagerado.
- Evita animaciones grandes o decorativas. ELEMENT debe sentirse profesional, no jugueton.
- Respeta `prefers-reduced-motion` con `motion-safe:` en Tailwind y fallback global en CSS.

## Tokens Tailwind v4

Agregar en `element-cotizador/src/index.css`, dentro del bloque `@theme` existente:

```css
@theme {
  --ease-element: cubic-bezier(.2, .8, .2, 1);
  --ease-element-press: cubic-bezier(.4, 0, .2, 1);

  --animate-element-fade-in: elementFadeIn 200ms var(--ease-element);
  --animate-element-slide-down: elementSlideDown 300ms var(--ease-element);
  --animate-element-slide-up: elementSlideUp 260ms var(--ease-element);
  --animate-element-modal: elementModal 300ms var(--ease-element);
  --animate-element-toast: elementToast 300ms var(--ease-element);
  --animate-element-logo: elementLogo 520ms var(--ease-element);
  --animate-element-progress: elementProgress 700ms var(--ease-element);
}

@keyframes elementFadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes elementSlideDown {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes elementSlideUp {
  from { opacity: 0; transform: translateY(14px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes elementToast {
  from { opacity: 0; transform: translateY(-20px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes elementModal {
  from { opacity: 0; transform: translateY(-20px) scale(.95); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

@keyframes elementLogo {
  from {
    opacity: 0;
    transform: translateY(10px) scale(.92);
    box-shadow: 0 0 0 rgba(182, 148, 98, 0);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
    box-shadow: 0 8px 32px rgba(182, 148, 98, .3);
  }
}

@keyframes elementProgress {
  from { transform: scaleX(.08); opacity: .55; }
  to { transform: scaleX(1); opacity: 1; }
}
```

## Utilidades de componentes

Estas clases pueden agregarse debajo de `@theme` en `index.css` si se quiere mantener el JSX limpio:

```css
@utility element-pressable {
  transition-property: transform, opacity, border-color, background-color, color, box-shadow;
  transition-duration: 160ms;
  transition-timing-function: var(--ease-element-press);
  will-change: transform;
}

@utility element-card-hover {
  transition-property: transform, border-color, background-color, box-shadow;
  transition-duration: 220ms;
  transition-timing-function: var(--ease-element);
}

@media (hover: hover) {
  .element-card-hover:hover {
    transform: translateY(-2px);
    border-color: color-mix(in srgb, var(--color-accent) 55%, var(--color-line));
    box-shadow: 0 16px 44px rgba(0, 0, 0, .32);
  }
}

.element-pressable:active {
  opacity: .82;
  transform: scale(.98);
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: .01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: .01ms !important;
  }
}
```

## Ejemplo: login

```tsx
export function LoginPage() {
  return (
    <main className="wrap">
      <div style={{ height: '15vh' }} />

      <div className="logo motion-safe:animate-element-logo">
        {/* Logo SVG */}
      </div>

      <div className="card motion-safe:animate-element-slide-up">
        <h1 className="text-center">ELEMENT</h1>
        <p className="small text-center">Cotizador Profesional</p>

        <div className="mt-6 grid gap-3">
          <input className="input transition-colors duration-200 focus:border-accent" placeholder="Usuario" />
          <input className="input transition-colors duration-200 focus:border-accent" type="password" placeholder="Contrasena" />
          <button className="btn element-pressable">INGRESAR</button>
        </div>
      </div>
    </main>
  )
}
```

## Ejemplo: dashboard cards

```tsx
<div className="grid mt-2">
  {[
    { title: 'Nueva', subtitle: 'Cotizacion' },
    { title: 'Ajustes', subtitle: 'Configurar' },
  ].map((item, index) => (
    <button
      key={item.title}
      className="card element-card-hover element-pressable text-left motion-safe:animate-element-slide-up"
      style={{ animationDelay: `${index * 70}ms` }}
      type="button"
    >
      <h3>{item.title}</h3>
      <p className="small">{item.subtitle}</p>
    </button>
  ))}
</div>
```

## Ejemplo: wizard de cotizacion

```tsx
function StepShell({ step, total, children }: { step: number; total: number; children: React.ReactNode }) {
  const progress = `${(step / total) * 100}%`

  return (
    <section className="motion-safe:animate-element-slide-up">
      <p className="step-indicator">Paso {step} de {total}</p>

      <div className="mb-4 h-1.5 overflow-hidden rounded-full bg-line">
        <div
          className="h-full origin-left rounded-full bg-accent motion-safe:animate-element-progress"
          style={{ width: progress }}
        />
      </div>

      {children}
    </section>
  )
}
```

## Ejemplo: formulario inline

```tsx
<div className="inline-form motion-safe:animate-element-slide-down">
  <input className="input mb-2" placeholder="Nombre del servicio" />
  <input className="input mb-2" inputMode="numeric" placeholder="Valor" />
  <button className="btn element-pressable">AGREGAR SERVICIO</button>
</div>
```

## Ejemplo: servicio seleccionable

```tsx
<button
  className={[
    'service-item element-pressable',
    selected ? 'selected' : '',
  ].join(' ')}
  type="button"
>
  <span>Diseno Arquitectonico</span>
  <strong className="text-accent">$7.000/m2</strong>
</button>
```

## Ejemplo: modal

```tsx
<div className="modal-overlay motion-safe:animate-element-fade-in">
  <div className="modal motion-safe:animate-element-modal">
    <h3>Guardar cotizacion</h3>
    <p>Revisa los datos antes de finalizar el proyecto.</p>
    <div className="modal-buttons">
      <button className="btn btn-secondary element-pressable">Cancelar</button>
      <button className="btn element-pressable">Guardar</button>
    </div>
  </div>
</div>
```

## Ejemplo: notificacion

```tsx
<div className="notification-container">
  <div className="notification success motion-safe:animate-element-toast">
    Cotizacion guardada correctamente
  </div>
</div>
```

## Checklist antes de usar

- La animacion comunica una accion o cambio de estado claro.
- No bloquea lectura, captura de datos ni navegacion con una mano.
- Usa `motion-safe:` cuando el movimiento no sea indispensable.
- Mantiene el acento dorado como detalle, no como decoracion excesiva.
- En mobile de 430px no desplaza la barra inferior ni corta botones.
