# Paleta de Colores

La paleta oficial esta definida en `vite-project/src/index.css`.

## Tokens actuales

| Token | Valor | Uso |
|---|---:|---|
| `--color-primary` | `#0047CC` | Azul principal, links, botones secundarios, lineas de graficas |
| `--color-primary-dark` | `#003399` | Hover, gradientes y estados intensos |
| `--color-primary-light` | `#3366FF` | Estados suaves, detalles y apoyo visual |
| `--color-accent` | `#F4B400` | CTA principal, destacados, puntos de interes |
| `--color-accent-dark` | `#D49A00` | Hover de CTA amarillo |
| `--color-bg` | `#FFFFFF` | Fondo principal |
| `--color-bg-alt` | `#F5F7FA` | Secciones alternas |
| `--color-bg-dark` | `#0A1628` | Paneles oscuros, headers IA, footer o contraste fuerte |
| `--color-text` | `#1E293B` | Titulos y texto principal |
| `--color-text-light` | `#64748B` | Texto secundario |
| `--color-text-inverse` | `#FFFFFF` | Texto sobre fondos oscuros |
| `--color-border` | `#E2E8F0` | Bordes suaves |
| `--color-success` | `#10B981` | Estados correctos o crecimiento |
| `--color-warning` | `#F59E0B` | Alertas leves |
| `--color-danger` | `#EF4444` | Errores, pendientes negativas o riesgos |

## Uso recomendado

### Azul principal

El azul `#0047CC` representa educacion, confianza, inteligencia y tecnologia. Debe dominar navbar activa, botones secundarios, graficas principales y acentos institucionales.

### Amarillo/Dorado

El amarillo `#F4B400` es el color de accion. Usarlo en:

- CTA principal;
- puntos clave;
- linea vertical de limite;
- detalles que necesiten atencion inmediata.

No usarlo para texto largo.

### Blanco y grises

El blanco sostiene claridad y profesionalismo. Los grises `#F5F7FA`, `#E2E8F0` y `#64748B` ayudan a separar secciones, cards y textos secundarios.

### Azul oscuro

`#0A1628` funciona para paneles de alto contraste, encabezados de IA o secciones institucionales oscuras. Siempre usar texto blanco o muy claro encima.

## Reglas de contraste

- Texto normal sobre fondo claro: usar `#1E293B` o `#64748B` segun jerarquia.
- Texto sobre azul oscuro: usar `#FFFFFF` o blanco con opacidad alta.
- CTA amarillo debe usar texto oscuro, no blanco, para conservar contraste.
- Mensajes de error deben usar fondo rojo claro y texto rojo oscuro cuando sea posible.

## No hacer

- No crear nuevos azules si los tokens actuales cubren el caso.
- No convertir la interfaz en monocromatica azul.
- No usar amarillo para fondos grandes.
- No mezclar paletas moradas, neon o beige sin justificacion de marca.
