# Paleta de Colores — {{PROYECTO}}

Fuente oficial: `{{RUTA_ESTILOS_GLOBALES}}`.

## Tokens

<!-- COMPLETAR: copiar los tokens reales; si no existen, crear la paleta a partir de los colores de marca y registrar la decisión. -->

| Token | Valor | Uso |
|---|---:|---|
| `--color-primary` | `{{COLOR_PRIMARIO}}` | Acciones secundarias, links, estados activos |
| `--color-accent` | `{{COLOR_ACENTO}}` | CTA principal, puntos de atención |
| `--color-bg` | `{{COLOR_FONDO}}` | Fondo principal |
| `--color-text` | `{{COLOR_TEXTO}}` | Texto principal |
| `--color-text-muted` | | Texto secundario |
| `--color-border` | | Bordes suaves |
| `--color-success` | | Éxito (verde por convención, H4) |
| `--color-warning` | | Advertencias |
| `--color-danger` | | Errores y acciones destructivas (rojo por convención, H4) |

## Reglas de contraste

- Texto normal: contraste mínimo 4.5:1 (WCAG AA); texto grande: 3:1.
- Verificar el texto sobre el color de acento: elegir texto claro u oscuro según el contraste real.
- Si hay modo oscuro, definir cada token también para el modo oscuro.

## No hacer

- No crear colores nuevos si un token existente cubre el caso.
- No usar el color de acento para texto largo ni fondos grandes.
- No comunicar estados solo con color (acompañar con texto o icono).
