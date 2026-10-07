# Flujo de Desarrollo

1. Leer `context/project-context.md` y `architecture/rules.md`.
2. Si hay tablero (`ia_contexto/`), tomar la tarea con `project-manager`.
3. Ubicar el área afectada (`rg`/grep).
4. Si la tarea toca UI: revisar `frontend/` y aplicar `ux-heuristicas` (H1, H3, H5 y H9 como mínimo).
5. Hacer cambios pequeños y coherentes con el estilo actual.
6. Ejecutar `{{CMD_LINT}}` y `{{CMD_TEST}}` desde `{{DIR_APP}}`.
7. Ejecutar `{{CMD_BUILD}}` si se tocaron rutas, imports, dependencias o configuración.
8. Para cambios visuales: verificar en desktop y móvil (y en dispositivo/emulador si la app es móvil).
9. Si apareció una regla nueva o una instrucción repetida, actualizar `.agents/skills/`.

## Comandos

```bash
cd {{DIR_APP}}
{{CMD_LINT}}
{{CMD_TEST}}
{{CMD_BUILD}}
{{CMD_DEV}}
```
