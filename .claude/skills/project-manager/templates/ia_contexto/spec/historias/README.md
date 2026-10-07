# Historias de usuario

Un archivo por responsable (`<nombre>.md`) o por módulo (`<modulo>.md`). Bórralo si el proyecto no trabaja con historias.

Plantilla de archivo:

```markdown
# Historias — <responsable o módulo>

Fuente: <documento en fuentes/>
Formato: RF FOR IA (reglas, criterios Dado/Cuando/Entonces, contrato técnico y pruebas por historia).

| Sprint | Semanas | HU | Puntos |
|---|---|---|---|

## HU-001 — <título>
Como <rol>, quiero <acción>, para <beneficio>.
Requisito: RF-xxx · Puntos: N · Sprint: N

Reglas: RN-xxx
Criterios:
- Dado …, cuando …, entonces ….
Contrato: `POST /api/...` (request / response / errores)
Pruebas: TEST-RF-xxx-01 …
Tareas: {{PREFIJO_TAREAS}}-0XXa (backend), {{PREFIJO_TAREAS}}-0XXb (frontend), {{PREFIJO_TAREAS}}-0XXc (pruebas)
```
