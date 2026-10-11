# Instrucciones de Frontend — Sistema de Gestión Documental (SGD)

## Stack

React + TypeScript + Vite + Tailwind v4 + shadcn/ui (frontend NOVA_FT); Supabase PostgreSQL; n8n; backend por definir (ver ia_contexto/spec/decisiones.md P-11)

## Reglas generales

- Respetar la estructura de carpetas de `architecture/rules.md`.
- Usar los tokens de `NOVA_FT/src/styles/theme.css` antes de crear colores, sombras o radios nuevos.
- Colores: solo la paleta institucional de `color-palette.md` (`navy`, `orange`, `gold`, `beige`, `beigeAlt`, `text`, `muted`, `card`, `border`). Sin hex hardcodeados en componentes reutilizables.
- Evitar dependencias nuevas si una solución simple encaja con el stack actual.
<!-- COMPLETAR: reglas propias del sistema de estilos (CSS modules, Tailwind, styled-components, StyleSheet de RN…). -->

## Componentes

- Nombres claros y orientados al dominio.
- Una responsabilidad por componente; extraer helpers y hooks cuando la lógica crezca.
- Todo componente con datos tiene sus estados: vacío, cargando, error y éxito (H1, H9).

## Contenido visible

- Idioma y tono: español, institucional, claro y directo (lenguaje archivístico del cliente: asunto, TRD, FUID, transferencia).
- Labels y CTA accionables (verbo + objeto: "Guardar cambios", "Crear cuenta").
- Mensajes de error que digan qué pasó y cómo corregirlo, sin culpar al usuario (H9).

## Validación

```bash
cd {{DIR_APP}}
{{CMD_LINT}}
{{CMD_BUILD}}
```

Para cambios visuales, revisar manualmente desktop y móvil.
