---
name: ux-heuristicas
description: Diseño y evaluación de usabilidad para apps web y móviles con las 10 heurísticas de Nielsen, sus checklists y las métricas de efectividad, eficiencia y satisfacción. Úsala al diseñar pantallas o flujos, revisar una interfaz, preparar o analizar una prueba de usabilidad, o cuando pidan "evaluación heurística", "checklist de usabilidad" o "revisar la UX".
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# UX Heurísticas — Web y Móvil

Base: clase HCI (heurísticas de Nielsen + fórmulas de calidad en usabilidad), con adaptaciones para móvil.

## Cuándo usarla

1. **Al diseñar** una pantalla, componente o flujo: recorre las 10 heurísticas como requisitos antes de escribir código.
2. **Al revisar** una interfaz existente: haz una evaluación heurística con `references/checklist-nielsen.md`.
3. **Al probar con usuarios**: calcula efectividad, eficiencia y satisfacción con `references/metricas-usabilidad.md`.

## Las 10 heurísticas (resumen accionable)

| # | Heurística | Regla de diseño | Web | Móvil |
|---|---|---|---|---|
| H1 | Visibilidad del estado del sistema | Siempre decir qué está pasando, con feedback a tiempo | Item activo en el menú, breadcrumbs, spinners o barras de progreso, toasts | Indicador de carga en el botón, skeletons, haptics/feedback al tocar, estado offline visible |
| H2 | Coincidencia con el mundo real | Hablar el lenguaje del usuario, orden lógico, metáforas reales | Textos sin jerga ni códigos | Iconos reconocibles por la plataforma (iOS/Android), formatos locales de fecha y moneda |
| H3 | Control y libertad | Salidas de emergencia: deshacer, cancelar, volver | Deshacer, volver a pasos anteriores, link a inicio | Botón atrás de Android y swipe-back de iOS funcionan, "Deshacer" en snackbar, cerrar modales y bottom sheets |
| H4 | Consistencia y estándares | Mismos elementos, nombres y comportamiento en todas las vistas | Navegación, colores semánticos (rojo = error, verde = éxito), X = cerrar | Seguir Material/HIG, tab bar fija, misma posición de las acciones principales |
| H5 | Prevención de errores | Evitar que el error ocurra | Confirmar acciones críticas, validación en línea, valores por defecto, selects en vez de texto libre | Teclado correcto (`inputmode`/`keyboardType`), pickers, botones deshabilitados hasta que el formulario sea válido |
| H6 | Reconocer en vez de recordar | Opciones visibles; el usuario no debe memorizar | Breadcrumbs ("Está aquí: Inicio / …"), autocompletar, conservar lo ya llenado | Etiquetas visibles (no solo placeholder), recientes/favoritos, conservar el estado al rotar o volver a la app |
| H7 | Flexibilidad y eficiencia | Sirve a principiantes y a expertos | Atajos de teclado, búsqueda global, personalización, no pedir datos dos veces | Gestos **con alternativa visible**, autocompletar, biometría, deep links, responsive del móvil al escritorio |
| H8 | Diseño estético y minimalista | Solo lo relevante; nada ornamental ni repetido | Jerarquía clara, buen contraste, sin saturar | Una acción principal por pantalla, divulgación progresiva, targets táctiles de 44–48 px como mínimo |
| H9 | Reconocer, diagnosticar y recuperarse de errores | El mensaje explica causa y solución, sin culpar | Lenguaje común, sin códigos, con la acción para corregir junto al campo | Error junto al campo, reintentar cuando falla la red, nunca borrar lo que el usuario escribió |
| H10 | Ayuda y documentación | Ayuda breve, orientada a la tarea y fácil de encontrar | Ayuda contextual, tooltips, FAQ por tarea | Onboarding corto que se pueda omitir, empty states que enseñan, ayuda en contexto |

## Flujo: evaluación heurística

1. Define el alcance: pantallas o flujos y la plataforma (web, móvil o ambas).
2. Recorre el flujo como usuario real (si hay app corriendo, navégala; si no, revisa el código y los mockups).
3. Llena el checklist de `references/checklist-nielsen.md` marcando **SÍ / NO / N/A** y comentario.
   - **Atención:** algunos ítems están redactados en negativo (marcados con ⚠). Ahí **NO es lo correcto**.
4. Por cada incumplimiento registra un hallazgo:

```markdown
### [H5] El formulario de registro permite enviar un correo inválido
- Pantalla: /registro
- Severidad: 3 (0 = no es problema · 1 = cosmético · 2 = menor · 3 = mayor · 4 = catástrofe)
- Evidencia: se envía "juan@" y el error aparece solo después de llamar al servidor
- Recomendación: validar en línea al salir del campo, con un mensaje que diga cómo corregirlo
```

5. Cierra con el **% de cumplimiento por heurística** = (ítems cumplidos × 100) / (ítems aplicables) y el top 5 de hallazgos por severidad.

## Flujo: prueba con usuarios

1. Define las tareas, sus subtareas y el tiempo estimado de cada una **antes** de la prueba.
2. Registra por usuario las subtareas completadas y el tiempo empleado.
3. Aplica la encuesta de satisfacción (escala 1–5).
4. Calcula las métricas con `references/metricas-usabilidad.md` (incluye un script).
5. Reporta por tarea y global, y cruza los resultados con los hallazgos heurísticos.

## Reglas al implementar UI

- Ninguna pantalla nueva se da por terminada sin pasar H1, H3, H5 y H9 (estados de carga, salida, prevención y errores).
- Todo estado tiene su diseño: vacío, cargando, error, éxito y sin conexión (móvil).
- No depender solo del color para comunicar un estado (texto + icono).
- Si el proyecto tiene `frontend/` o un design system, las heurísticas complementan esas reglas; no las reemplazan.
