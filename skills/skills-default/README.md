# Kit de Skills por Defecto — Web y Móvil

Kit genérico de skills para agentes IA (Claude Code, Codex, etc.). No trae datos de ningún proyecto: se copia a un repo nuevo y se adapta con la skill `project-setup`.

## Cómo usarlo en un proyecto nuevo

1. Copia **el contenido** de esta carpeta en `<repo>/.agents/skills/`.
2. Pídele al agente: **"Usa la skill project-setup para adaptar las skills a este proyecto"**.
3. El agente detecta el stack, te pregunta lo que falta (producto, marca, plataforma) y llena todos los `{{...}}`.
4. Verifica que no queden `{{` ni `COMPLETAR` (lo hace `project-setup` al final).

## Estructura

| Carpeta | Tipo | Qué es |
|---|---|---|
| `project-setup/` | skill | Adapta el kit a un proyecto nuevo. **Empieza aquí.** |
| `ux-heuristicas/` | skill | Heurísticas de Nielsen, checklists y métricas de usabilidad (web y móvil) |
| `project-manager/` | skill | Tablero de tareas, specs (`ia_contexto/`) e historial |
| `desarrollo/`, `testing/`, `seguridad/` | skill (plantilla) | Convenciones, verificación y seguridad del proyecto |
| `frontend-design/`, `frontend-aesthetics/` | skill | Dirección estética y calidad visual |
| `animation-creator/`, `css-inspector/` | skill | Animaciones CSS y depuración de cascada |
| `tailwind-css-patterns/` | skill | Patrones Tailwind v4 (+ `references/motion-system.md` como plantilla) |
| `typescript-advanced-types/` | skill | Tipos avanzados de TypeScript |
| `context/`, `memory/`, `architecture/`, `agents/`, `tools/`, `workflows/`, `prompts/`, `frontend/` | plantillas | Contexto vivo del proyecto (se llenan en el setup) |

## Proyecto

<!-- COMPLETAR: lo llena project-setup -->
**{{PROYECTO}}** — {{DESCRIPCION_PRODUCTO}}
Plataforma: {{PLATAFORMA}} · Stack: {{STACK}}

## Prioridades para agentes

- Leer `context/project-context.md` y `architecture/rules.md` antes de tocar código.
- Diseñar y revisar la UI con `frontend/` + `ux-heuristicas`.
- Validar con `{{CMD_LINT}}`, `{{CMD_TEST}}` y `{{CMD_BUILD}}` desde `{{DIR_APP}}`.
- No agregar dependencias, frameworks ni backend sin una decisión explícita registrada en `memory/`.

## Mantenimiento

Si una instrucción, decisión, patrón o corrección se repite más de una vez, se documenta en el archivo correspondiente (ver `workflows/skill-maintenance.md`). Las próximas sesiones no deben depender de recordar conversaciones anteriores.
