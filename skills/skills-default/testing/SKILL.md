---
name: testing
description: Estrategia, comandos y criterio de "verificado" de {{PROYECTO}}. Úsala para comprobar que una tarea está lista antes de cerrarla.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Testing — {{PROYECTO}}

## Estado actual

<!-- COMPLETAR: framework de tests configurado (Vitest, Jest, Flutter test, Playwright, Detox…) o "no configurado" + tarea {{PREFIJO_TAREAS}}-XXX para integrarlo. -->

## Verificación mínima obligatoria

```bash
cd {{DIR_APP}}
{{CMD_LINT}}
{{CMD_TEST}}
{{CMD_BUILD}}
```

Resultado esperado: los tres sin errores. Sin ejecución real no hay verificación.

## Verificación adicional

- Revisar manualmente la ruta o pantalla modificada con `{{CMD_DEV}}`.
- Sin errores en la consola del navegador / en el log del dispositivo.
- Web: probar en un ancho de móvil (~375 px) y en desktop.
- Móvil: probar en emulador o dispositivo <!-- COMPLETAR: cuáles -->.
- UI nueva o rediseñada: checklist mínimo de `ux-heuristicas` (H1, H3, H5, H9).

## Estrategia objetivo

- **Unitario**: funciones puras, helpers y reglas de negocio.
- **Componente**: render y comportamiento de componentes.
- **Integración**: flujos de navegación y llamadas a servicios (con mocks).
- **E2E**: flujos críticos (Playwright en web; Detox/Maestro en móvil).
- **Usabilidad**: pruebas con usuarios y métricas de `ux-heuristicas/references/metricas-usabilidad.md`.

## Cobertura esperada

<!-- COMPLETAR: meta inicial (ej. reglas de negocio críticas al 100 %, global ≥ 60 %). -->
