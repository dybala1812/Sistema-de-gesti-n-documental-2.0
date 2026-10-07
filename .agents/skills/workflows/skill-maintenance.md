# Flujo de Mantenimiento de Skills

Usar este flujo cuando una instruccion se repite, una decision se vuelve permanente o aparece una regla que ayudara a futuras sesiones.

## Cuando actualizar skills

Actualizar `.agents/skills/` cuando:

- el usuario repite una preferencia de diseno, arquitectura o flujo;
- se descubre una convencion importante del proyecto;
- una correccion probablemente se repetira en futuras tareas;
- un prompt o checklist empieza a usarse mas de una vez;
- una decision tecnica afecta a varios archivos o modulos;
- se agrega una herramienta, dependencia o proceso nuevo.

## Donde documentar

- `frontend/`: UI, diseno, paleta, responsive, accesibilidad y componentes.
- `architecture/`: reglas tecnicas, estructura de carpetas, limites entre modulos.
- `context/`: descripcion del producto, stack, rutas, dominio y estado general.
- `memory/`: decisiones tomadas, riesgos conocidos y aprendizajes del proyecto.
- `prompts/`: prompts reutilizables para IA o revision de contenido.
- `workflows/`: pasos repetibles para desarrollo, QA, contenido o deploy.
- `tools/`: comandos, scripts, variables y herramientas.

## Como escribir una actualizacion

- Ser concreto y accionable.
- Evitar duplicar informacion ya documentada.
- Incluir rutas cuando la regla dependa de archivos especificos.
- Separar reglas permanentes de notas temporales.
- Mantener el tono claro para que otro agente pueda actuar sin preguntar de nuevo.

## Frase guia

"Si esto me va a servir otra vez, debe vivir en una skill o documento de `.agents/skills/`."
