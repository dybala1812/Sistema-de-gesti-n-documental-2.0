# Reglas de Arquitectura — Sistema de Gestión Documental (SGD)

## Principios

- Mantener la arquitectura actual (React + TypeScript + Vite + Tailwind v4 + shadcn/ui (frontend NOVA_FT); Supabase PostgreSQL; n8n; backend por definir (ver ia_contexto/spec/decisiones.md P-11)) mientras no haya una necesidad real de cambiarla; los cambios grandes se registran en `memory/`.
- Una responsabilidad por módulo/componente. Si un archivo mezcla UI, lógica de negocio y acceso a datos, extraer progresivamente.
- Si una regla, patrón o instrucción se vuelve repetitiva, documentarla en `.agents/skills/`.

## Estructura de carpetas

<!-- COMPLETAR: árbol real del proyecto y qué va en cada carpeta (páginas/pantallas, componentes, datos, servicios, hooks, utilidades). -->

## Datos y servicios

<!-- COMPLETAR: de dónde vienen los datos (API, BaaS, local), dónde se centraliza el acceso y cómo se manejan errores y estados de carga. -->

## Seguridad

- Ver la skill `seguridad`.
- Ningún secreto en el código del cliente. Las claves de APIs de pago van detrás de un backend/proxy.

## UI

- Seguir `frontend/` y la skill `ux-heuristicas`.
- Usar los tokens de `NOVA_FT/src/styles/theme.css` antes de crear colores, sombras o radios nuevos.
- Accesibilidad: contraste, labels, foco visible, texto alternativo y navegación por teclado/lector de pantalla.

## Calidad

- Tipos, lint y tests de la parte tocada antes de cerrar cambios de código (comandos en `testing/SKILL.md`).
- Build (backend `npm run build`, frontend `npx vite build`) cuando se toquen rutas, imports, configuración o dependencias.
- Revisión manual de las pantallas afectadas en desktop y móvil.
