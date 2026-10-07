# Flujo de Desarrollo

1. Leer contexto en `.agents/skills/context/project-context.md`.
2. Revisar reglas en `.agents/skills/architecture/rules.md`.
3. Ubicar el area afectada con `rg`.
4. Hacer cambios pequenos y coherentes con el estilo actual.
5. Ejecutar `npm run lint` desde `vite-project/`.
6. Ejecutar `npm run build` si se tocaron rutas, imports, dependencias o componentes principales.
7. Para cambios visuales, abrir la app y verificar escritorio y movil.
8. Si aparecio una instruccion repetitiva o una regla nueva, actualizar el archivo correspondiente en `.agents/skills/`.

## Comandos

```powershell
cd vite-project
npm run lint
npm run build
npm run dev
```
