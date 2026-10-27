# Flujo de Desarrollo

1. Leer `context/project-context.md` y `architecture/rules.md`.
2. Si hay tablero (`ia_contexto/`), tomar la tarea con `project-manager`.
3. Crear la rama de la tarea según la skill `git`.
4. Ubicar el área afectada (`rg`/grep).
5. Si la tarea toca UI: revisar `frontend/` y aplicar `ux-heuristicas` (H1, H3, H5 y H9 como mínimo).
6. Hacer cambios pequeños y coherentes con el estilo actual.
7. Ejecutar las verificaciones de la parte tocada (ver "Comandos"): backend tipos, lint y tests; BD `probar_local.sh`; frontend `typecheck`.
8. Ejecutar el build (backend `npm run build`, frontend `npx vite build`) si se tocaron rutas, imports, dependencias o configuración.
9. Para cambios visuales: verificar en desktop y móvil (y en dispositivo/emulador si la app es móvil).
10. Si apareció una regla nueva o una instrucción repetida, actualizar `.agents/skills/`.
11. Commit convencional con el ID de la tarea y pull request según la skill `git`.

## Comandos

```bash
# Backend — desde backned_sistema_gestion_documental/
npx tsc --noEmit -p .       # tipos: 0 errores
npm run lint                # ESLint: 0 errores
npm test                    # pruebas unitarias (node --test "tests/**/*.test.mjs")
npm run build               # build de producción (Next.js)

# Base de datos — desde la raíz, en Git Bash (requiere PostgreSQL 18 local)
bash database/scripts/probar_local.sh   # migraciones en BD temporal + pruebas_reglas.sql + concurrencia de consecutivos

# Frontend — desde NOVA_FT/ (no tiene tests ni linter)
npm run typecheck           # línea base: 28 errores, todos en código original de NOVA; no agregar nuevos
npx vite build              # build (npm run build corre tsc primero y se detiene por la línea base de NOVA)
```

Solo se corre lo de la parte que se tocó. Si `npx` falla por los espacios de la ruta: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json` y `node node_modules/vite/bin/vite.js build`.
