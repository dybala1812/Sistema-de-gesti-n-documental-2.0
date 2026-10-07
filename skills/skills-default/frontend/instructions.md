# Instrucciones de Frontend — {{PROYECTO}}

## Stack

{{STACK}}

## Reglas generales

- Respetar la estructura de carpetas de `architecture/rules.md`.
- Usar los tokens de `{{RUTA_ESTILOS_GLOBALES}}` antes de crear colores, sombras o radios nuevos.
- Evitar dependencias nuevas si una solución simple encaja con el stack actual.
<!-- COMPLETAR: reglas propias del sistema de estilos (CSS modules, Tailwind, styled-components, StyleSheet de RN…). -->

## Componentes

- Nombres claros y orientados al dominio.
- Una responsabilidad por componente; extraer helpers y hooks cuando la lógica crezca.
- Todo componente con datos tiene sus estados: vacío, cargando, error y éxito (H1, H9).

## Contenido visible

- Idioma y tono: {{TONO}}.
- Labels y CTA accionables (verbo + objeto: "Guardar cambios", "Crear cuenta").
- Mensajes de error que digan qué pasó y cómo corregirlo, sin culpar al usuario (H9).

## Validación

```bash
cd {{DIR_APP}}
{{CMD_LINT}}
{{CMD_BUILD}}
```

Para cambios visuales, revisar manualmente desktop y móvil.
