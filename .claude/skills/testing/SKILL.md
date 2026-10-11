---
name: testing
description: Estrategia, comandos y criterio de "verificado" de Sistema de Gestión Documental (SGD). Úsala para comprobar que una tarea está lista antes de cerrarla.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Testing — Sistema de Gestión Documental (SGD)

## Estado actual

Frontend `NOVA_FT/`: sin framework de tests ni linter configurado; solo `npm run typecheck` y `npm run build`. Backend: aún no existe (P-11). Configurarlo es parte de SGD-004/SGD-008.

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

Meta del F-02 (RNF-AC-09): **≥ 60 %** en consecutivos, estados y permisos. Recomendado: reglas RN-AC-* críticas al 100 %.

## Pruebas obligatorias del módulo Archivo Central

Casos de la matriz de trazabilidad (`ia_contexto/spec/trazabilidad.md`); una tarea no se cierra sin su caso en verde. Los más críticos:

| Área | Caso | Regla |
|---|---|---|
| Consecutivos | N inserciones concurrentes → números únicos y secuenciales por tipo; reinicio al cambiar de año. | RN-AC-08 |
| Estados | Solo transiciones válidas de `business-rules.md`; enviar respuesta fallido no cierra. | RN-AC-09 |
| Permisos | Dependencia no ve otra dependencia; RA no ve retirados/graduados; intento denegado queda auditado. | RF-AC-023 |
| Duplicados | Mismo archivo en el mismo expediente → rechazado. | RN-AC-11 |
| Correo | Mismo Message-ID leído dos veces → una sola comunicación; respuesta sin etiqueta → se asocia por In-Reply-To. | RNF-AC-04 |
| Idempotencia | Importar el mismo Excel histórico dos veces → sin duplicados. | RF-AC-019 |
| Transferencias | En 2026, transferencia del año 2025 → bloqueada. | RN-AC-03 |
| Anulación | Anular → el registro sigue en la BD. | RN-AC-12 |
| IA | Sugerencia nunca cambia la clasificación sin confirmación. | RN-AC-13 |

RNF a medir (SGD-070): búsqueda < 3 s con 50.000 docs; correo visible ≤ 5 min; restauración de respaldo probada; carga + clasificación < 3 min con usuario real.

Datos de prueba: **siempre ficticios** (Ley 1581).
