# Paleta de Colores Institucional — Sistema de Gestión Documental

> **Referencia obligatoria.** Consultar esta paleta antes de escribir o revisar cualquier UI, plantilla, documento o servicio integrado.

## Objetivo

Mantener coherencia visual institucional, mejorar el reconocimiento de marca y asegurar consistencia entre proyectos web, módulos y servicios integrados.

## Paleta oficial

| Token | Valor | Nombre | Uso recomendado |
|---|---|---|---|
| `beige` | `#f3ede1` | Fondo principal | Portadas, fondos de sección y plantillas base |
| `beigeAlt` | `#ede6d8` | Fondo alterno | Bandas secundarias y separadores visuales |
| `navy` | `#1e3a5f` | Azul institucional | Títulos, encabezados y elementos de autoridad |
| `orange` | `#e8740e` | Naranja de acción | Llamados a la acción y resaltados de prioridad |
| `gold` | `#c89b14` | Dorado institucional | Subtítulos, indicadores y jerarquía secundaria |
| `text` | `#2c3e50` | Texto principal | Contenido normativo y cuerpo documental |
| `muted` | `#6b7a8d` | Texto de apoyo | Notas, subtítulos y metadatos |
| `card` | `#ffffff` | Superficie | Tablas, paneles y contenedores |
| `border` | `rgba(30,58,95,0.09)` | Borde tenue | Separadores y delimitadores |

## Reglas de aplicación

1. Todo nuevo desarrollo debe usar primero estos tokens antes de introducir colores nuevos.
2. No usar colores hardcodeados en componentes reutilizables cuando exista token equivalente.
3. Botón primario: `navy`; acción secundaria o highlight: `orange`; acento informativo: `gold`.
4. El texto de lectura continua debe priorizar `text`; metadatos y apoyos en `muted`.
5. Los fondos base deben alternar `beige` y `beigeAlt` para jerarquía visual suave.
6. Validar contraste y legibilidad en desktop y mobile.

## Contraste medido (WCAG 2.1)

| Combinación | Ratio | Resultado |
|---|---:|---|
| Blanco sobre `navy` | 11.5:1 | ✅ AA/AAA — botón primario seguro |
| `navy` sobre `beige` | 9.9:1 | ✅ AAA |
| `text` sobre `beige` | 9.4:1 | ✅ AAA |
| `navy` sobre `orange` | 3.8:1 | ⚠️ Solo texto grande (≥ 18.66 px bold / 24 px) |
| Blanco sobre `orange` | 3.0:1 | ⚠️ Solo texto grande en bold |
| `muted` sobre `card` | 4.4:1 | ⚠️ Roza AA: usar ≥ 14 px bold o texto no esencial |
| `muted` sobre `beige` | 3.8:1 | ⚠️ Solo texto grande o metadatos no críticos |
| `navy` sobre `gold` | 4.5:1 | ✅ AA (justo) |
| `gold` sobre `beige` / `card` | 2.2–2.6:1 | ❌ No usar `gold` como color de texto sobre fondos claros |

Consecuencias prácticas:
- Botones `orange`: texto en bold y tamaño ≥ 16–18 px, o usar `orange` como borde/fondo de highlight con texto `navy`.
- `gold`: usarlo en indicadores, líneas, iconos, badges con texto `navy`, nunca como texto corrido sobre `beige` o `card`.
- Información crítica nunca en `muted`; usar `text`.

## Estados semánticos

La paleta institucional no define colores de estado. Mientras no exista decisión oficial, mantener los del tema actual: éxito verde, advertencia ámbar, error `#d32f2f`, siempre acompañados de texto o icono (no comunicar solo con color).

## Implementación en el código

Fuente de los tokens en el frontend: `NOVA_FT/src/styles/theme.css` (variables CSS consumidas por Tailwind/shadcn).

Mapeo sugerido de los tokens institucionales a las variables del tema:

| Variable del tema | Token institucional |
|---|---|
| `--background` | `beige` |
| `--foreground` / `--primary` / `--sidebar` | `navy` |
| `--secondary` / `--ring` / `--sidebar-primary` | `orange` |
| `--accent` | `gold` |
| `--card` / `--popover` / `--input-background` | `card` |
| `--muted` | `beigeAlt` |
| `--muted-foreground` | `muted` |
| `--border` | `border` |

> ⚠️ A la fecha (2026-10-07) `theme.css` aún usa valores anteriores (`#ff9800` naranja, `#ffc107` amarillo, `#f8f9fa` fondo). Alinear con esta paleta cuando se toque el tema.

## No hacer

- No crear colores nuevos si un token existente cubre el caso.
- No usar `orange` para texto largo ni fondos grandes.
- No usar `gold` como color de texto sobre fondos claros.
- No comunicar estados solo con color.
