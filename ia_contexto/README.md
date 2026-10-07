# ia_contexto — {{PROYECTO}}

Estado del proyecto para agentes IA y para el equipo: **qué** falta, qué se decidió y qué se entregó.
El **cómo** (stack, convenciones, pruebas) vive en `.agents/skills/`. Lo gestiona la skill `project-manager`.

| Ruta | Qué va ahí |
|---|---|
| `tareas-faltantes.md` | Backlog, agrupado por sprint o por módulo |
| `tareas-por-realizar.md` | Tareas seleccionadas para trabajar ahora |
| `tareas-en-revision.md` | Implementadas; esperan verificación o revisión humana |
| `tareas-hechas.md` | Cerradas con evidencia |
| `historial.md` | Bitácora: qué se hizo, pruebas, decisiones y commits (lo más reciente arriba) |
| `spec/` | Versión operativa de los requisitos (formato RF FOR IA) |
| `spec/historias/` | Historias de usuario detalladas, un archivo por responsable o por módulo (opcional) |
| `spec/acceptance-tests/` | Escenarios Dado/Cuando/Entonces por módulo (opcional) |
| `fuentes/` | Documentos originales: especificación de requisitos, actas, enunciados, contratos (PDF/DOCX/MD) |
| `diseno/` | Maquetas, prototipos, capturas e interfaz de referencia |

Reglas rápidas:

- Un ID de tarea está en un solo archivo de tareas a la vez; moverla = quitarla del origen.
- Si `spec/` y un documento de `fuentes/` se contradicen, manda la fuente hasta que se decida; se registra en `spec/decisiones.md`.
- Ninguna skill vive dentro de `ia_contexto/`.
- No guardar aquí secretos, contraseñas ni datos personales reales.
