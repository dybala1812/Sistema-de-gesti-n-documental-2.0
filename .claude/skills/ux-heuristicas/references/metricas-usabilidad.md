# Métricas de calidad en usabilidad

## Fórmulas

- **Efectividad (%)** = (n.º de subtareas realizadas × 100) / (n.º de subtareas definidas)
- **Eficiencia (%)** = (tiempo estimado por tarea × 100) / (tiempo empleado)
  - Más de 100 % = el usuario fue más rápido de lo estimado. Reporta el valor real y, si se pide, también el valor topado en 100 %.
- **Satisfacción** = (suma de las calificaciones de las preguntas) / (n.º de preguntas)
  - En escala 1–5. Para expresarla en %: satisfacción / 5 × 100.

Calcula por usuario y tarea, luego el promedio por tarea y el global.

## Plantilla de registro

| Usuario | Tarea | Subtareas hechas / definidas | Tiempo estimado (min) | Tiempo empleado (min) | P1 | P2 | … |
|---|---|---|---|---|---|---|---|

## Script de cálculo (Python, sin dependencias)

```python
# datos: subtareas[usuario] = [hechas_T1, hechas_T2, ...]
def efectividad(hechas, definidas):
    return hechas * 100 / definidas

def eficiencia(t_estimado, t_empleado):
    return t_estimado * 100 / t_empleado

def satisfaccion(calificaciones):
    return sum(calificaciones) / len(calificaciones)

# Ejemplo (ejercicio de clase): 5 usuarios, 2 tareas de 3 subtareas, tiempos estimados de 3 y 4 min
subtareas = {1: [2, 3], 2: [1, 2], 3: [2, 3], 4: [3, 3], 5: [2, 1]}
tiempos   = {1: [4, 5], 2: [2, 3], 3: [5, 5], 4: [2, 5], 5: [3, 4]}
encuesta  = {1: [2, 4], 2: [3, 5], 3: [4, 2], 4: [3, 4], 5: [5, 4]}
DEFINIDAS, ESTIMADO = [3, 3], [3, 4]

for t in range(2):
    ef = [efectividad(s[t], DEFINIDAS[t]) for s in subtareas.values()]
    efi = [eficiencia(ESTIMADO[t], tm[t]) for tm in tiempos.values()]
    print(f"T{t+1}: efectividad {sum(ef)/len(ef):.1f}% | eficiencia {sum(efi)/len(efi):.1f}%")
sat = [satisfaccion(c) for c in encuesta.values()]
print(f"Satisfaccion promedio: {sum(sat)/len(sat):.2f} / 5")
```

## Cómo interpretar

- Efectividad baja → la tarea no se puede completar: revisar H2, H5, H6 y H9.
- Eficiencia baja → la tarea se completa pero cuesta: revisar H1, H7 y H8.
- Satisfacción baja con buena efectividad → problema estético o de confianza: revisar H8 y H10.
