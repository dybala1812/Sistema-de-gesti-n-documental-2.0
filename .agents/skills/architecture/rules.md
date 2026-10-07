# Reglas de Arquitectura — {{PROYECTO}}

## Principios

- Mantener la arquitectura actual ({{STACK}}) mientras no haya una necesidad real de cambiarla; los cambios grandes se registran en `memory/`.
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
- Usar los tokens de `{{RUTA_ESTILOS_GLOBALES}}` antes de crear colores, sombras o radios nuevos.
- Accesibilidad: contraste, labels, foco visible, texto alternativo y navegación por teclado/lector de pantalla.

## Calidad

- `{{CMD_LINT}}` antes de cerrar cambios de código.
- `{{CMD_BUILD}}` cuando se toquen rutas, imports, configuración o dependencias.
- Revisión manual de las pantallas afectadas en desktop y móvil.
