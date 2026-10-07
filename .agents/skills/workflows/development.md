# Flujo de Desarrollo

1. Leer `context/project-context.md` y `architecture/rules.md`.
2. Si hay tablero (`ia_contexto/`), tomar la tarea con `project-manager`.
3. Crear la rama de la tarea según la skill `git`.
4. Ubicar el área afectada (`rg`/grep).
5. Si la tarea toca UI: revisar `frontend/` y aplicar `ux-heuristicas` (H1, H3, H5 y H9 como mínimo).
6. Hacer cambios pequeños y coherentes con el estilo actual.
7. Ejecutar `{{CMD_LINT}}` y `{{CMD_TEST}}` desde `{{DIR_APP}}`.
8. Ejecutar `{{CMD_BUILD}}` si se tocaron rutas, imports, dependencias o configuración.
9. Para cambios visuales: verificar en desktop y móvil (y en dispositivo/emulador si la app es móvil).
10. Si apareció una regla nueva o una instrucción repetida, actualizar `.agents/skills/`.
11. Commit convencional con el ID de la tarea y pull request según la skill `git`.

## Comandos

```bash
cd {{DIR_APP}}
{{CMD_LINT}}
{{CMD_TEST}}
{{CMD_BUILD}}
{{CMD_DEV}}
```
