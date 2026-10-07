# Especialización de Agentes — {{PROYECTO}}

Plantilla. `project-setup` ajusta las rutas reales y elimina los roles que no apliquen.

## Frontend UI Agent
Componentes, responsive, accesibilidad y consistencia visual.
- Revisa: <!-- COMPLETAR: carpetas de páginas/pantallas y componentes -->, `{{RUTA_ESTILOS_GLOBALES}}`, `.agents/skills/frontend/`
- Skills: `frontend-design`, `ux-heuristicas`, `animation-creator`

## Mobile Agent (si {{PLATAFORMA}} incluye móvil)
Navegación nativa, gestos, permisos, rendimiento en dispositivo, builds.
- Revisa: <!-- COMPLETAR: android/, ios/, app.json, navegación -->
- Skills: `ux-heuristicas` (ítems 📱), `testing`

## Logic / Data Agent
Servicios, estado, integraciones y reglas de negocio.
- Revisa: <!-- COMPLETAR: servicios, store, api -->, `ia_contexto/spec/`
- Skills: `desarrollo`, `seguridad`, `typescript-advanced-types` (si aplica)

## QA Agent
Pruebas, evaluación heurística y verificación antes de cerrar tareas.
- Skills: `testing`, `ux-heuristicas`

## Deploy Agent
Build, variables de entorno y publicación ({{HOSTING}}).
- Revisa: <!-- COMPLETAR: package.json, config de hosting, .env.example -->
- Skills: `seguridad`, `testing`
