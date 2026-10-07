---
name: testing
description: Estrategia y comandos de testing de EDUCALC XE. Úsala para verificar que una tarea está lista.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Testing — EDUCALC XE

## Estado actual

El proyecto **no tiene un framework de testing configurado**. Esta skill es una versión mínima; su primer tarea pendiente es evaluar e integrar Vitest + React Testing Library o Jest.

## Verificación mínima obligatoria (hoy)

Hasta que haya tests automatizados, toda tarea debe ejecutar:

```bash
cd vite-project
npm install
npm run lint
npm run build
```

Resultado esperado:

- `npm run lint` sin errores.
- `npm run build` finaliza correctamente y genera `vite-project/dist/`.

## Verificación adicional recomendada

- Revisar manualmente la ruta o componente modificado con `npm run dev` o `npm run preview`.
- Validar que no haya errores en la consola del navegador en la página afectada.

## Estrategia de testing objetivo

- **Unitario**: funciones puras de utilidades y helpers de matemáticas.
- **Componente**: renderizado y comportamiento de componentes React con React Testing Library.
- **Integración**: flujos de rutas con React Router.
- **Visual / E2E**: a considerar con Playwright para flujos críticos del laboratorio.

## Scripts de testing objetivo

Una vez configurado, se esperan scripts similares a:

```bash
npm run test        # ejecutar tests
npm run test:ui     # Vitest UI (opcional)
```

## Cobertura esperada

- Por definir una vez instalado el framework.
- Meta inicial: cubrir funciones matemáticas críticas y componentes de alta frecuencia de uso.

## Tarea de deuda técnica

- [ ] LH-002: Evaluar e integrar framework de testing (Vitest + React Testing Library recomendado).
