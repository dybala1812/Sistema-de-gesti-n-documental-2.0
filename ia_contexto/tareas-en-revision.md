# Tareas en revision — Sistema de Gestión Documental (SGD)

> Implementadas; falta verificación o revisión humana. Anotar Evidencia: y Pendiente:.

<!-- Ejemplo:

- [ ] SGD-005: Permisos por perfil y dependencia, auditoría inmutable y anulación sin borrado (HU-AC-18, RF-AC-023, RF-AC-024) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-023
  Tipo: feature
  Prioridad: alta
  Depende de: SGD-007, SGD-008
  Evidencia: las escrituras de catálogos, parámetros y plantillas pasan por funciones que fijan el usuario (la auditoría ya no queda sin usuario), revisan el permiso con fn_tiene_permiso y auditan los intentos denegados; pantalla Administración › Auditoría (filtros por fecha, acción, recurso y resultado; detalle con campos cambiados y motivo), GET /api/auditoria solo con auditoria.consultar; GET /api/transferencias/resumen ahora exige token (401 sin token). migración 17 (20261017000000_catalogos_parametros_auditoria.sql) con 22 pruebas nuevas en pruebas_reglas.sql: todas pasan con database/scripts/probar_local.sh; tsc y vite build sin errores nuevos; probado en navegador y con el backend (403 sin permiso, 401 sin token).
  Pendiente: aplicar las migraciones 16 y 17 en Supabase; revisión humana

- [ ] SGD-011: Tipos documentales, programas académicos y ubicaciones físicas (HU-AC-02, RF-AC-004) · 3 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-004
  Prioridad: media
  Depende de: SGD-010
  Evidencia: Catálogos › Tipos documentales, Programas académicos y Ubicaciones físicas con crear, editar, inactivar con motivo y nombre único validado por la base; Programas se importan desde Excel. Cubierto por las pruebas de la migración 17.
  Pendiente: confirmar con el cliente si se usan las ubicaciones físicas (RF-AC-004 lo deja pendiente); aplicar la migración 17; revisión humana

- [ ] SGD-087: [BUG] Catálogos: falla al crear un registro de forma manual
  Spec: ia_contexto/spec/requirements.md#rf-ac-001
  Tipo: bug
  Prioridad: alta
  Etiquetas: bug, catalogos
  Skills: desarrollo, testing
  Requisito: RF-AC-001, RF-AC-002, RF-AC-003, RF-AC-004
  Relacionado: SGD-010
  Pasos para reproducir: 1. Abrir Archivo Central › Catálogos. 2. Elegir una pestaña (dependencias, TRD, asuntos, tipos, programas u ubicaciones). 3. Pulsar crear / nuevo e intentar guardar un registro a mano (no por Excel).
  Esperado: el registro se crea, queda en la lista y se audita (RN-AC-12: sin borrado).
  Actual: sale un error y no se crea el ítem.
  Evidencia: causa: el CRUD anterior solo dejaba escribir al perfil Administrador y el usuario de Archivo Central recibía error; quedó resuelto con la escritura por fn_catalogo_guardar y el permiso catalogos.gestionar (conjunto 1). Probado con el backend: 201 al crear tipo documental, programa, dependencia y asunto, auditados con usuario_id 2; en navegador el asunto muestra "Registro creado". El duplicado ahora dice "Ya existe un registro con ese nombre en esta dependencia" y marca el campo nombre (antes señalaba dependencia_id). Los 4 registros de prueba quedaron inactivos con motivo (sin borrar); inactivar sin motivo responde 400 con campo motivo.
  Pendiente: revisión humana

- [ ] SGD-088: [BUG] Por clasificar, Clasificados y Archivo: la fila/tarjeta no abre la previsualización; solo el botón
  Spec: ia_contexto/spec/requirements.md#rf-ac-011
  Tipo: bug
  Prioridad: media
  Etiquetas: bug, ux, visor
  Skills: desarrollo, ux-heuristicas, frontend
  Requisito: RF-AC-011, RF-AC-013
  Relacionado: SGD-030, SGD-032, SGD-085
  Pasos para reproducir: 1. Ir a Por clasificar, Clasificados o Archivo. 2. Pulsar el cuadrito/fila del documento (fuera del botón Clasificar / Abrir PDF / Abrir).
  Esperado: toda la fila o tarjeta abre la misma vista previa del documento (visor + formulario o ficha). El botón de clasificar sigue siendo una acción, no el único punto de entrada.
  Actual: solo el botón abre el visor; el resto de la fila no es clicable.
  Archivos: NOVA_FT/src/app/pages/archivo-central/PorClasificar.tsx, Clasificados.tsx, Archivo.tsx (y ClasificarDocumento si aplica).
  Evidencia: Por clasificar, Clasificados y Archivo: toda la fila abre la misma vista que el botón (visor + formulario o ficha); la fila es enfocable con Tab y se abre con Enter o Espacio, con foco visible; los botones internos no disparan dos veces (stopPropagation). Probado en navegador con clic en una celda y con Enter en las tres pantallas. tsc del frontend 28 (línea base) y vite build OK. Archivos del compañero tocados por estar asignados en el tablero: PorClasificar.tsx, Clasificados.tsx y Archivo.tsx.
  Pendiente: revisión humana

- [ ] SGD-089: [BUG] Respuestas de error: JSON con número y motivo; consecutivo solo en error de sistema; formulario = descripción
  Spec: ia_contexto/spec/decisiones.md#decisiones
  Tipo: bug
  Prioridad: alta
  Etiquetas: bug, api, consecutivos
  Skills: desarrollo, seguridad, testing
  Requisito: RN-AC-08, RN-AC-15, D-21
  Relacionado: SGD-008, SGD-087
  Pasos para reproducir: 1. Provocar un error de formulario (campo vacío o duplicado en catálogos/comunicaciones). 2. Provocar un error de sistema al generar consecutivo (si se puede simular). 3. Ver el JSON y lo que muestra la pantalla.
  Esperado: error de sistema → `{ "error": "<número>", "motivo": "<por qué>" }` y `consecutivo` solo si el fallo es del sistema de consecutivos o el número ya existía. Error de formulario → `{ "error": "<descripción>", "campo"? }` sin número de sistema y **sin** consumir ni mostrar consecutivo. El frontend muestra ese texto (no un genérico de HTTP).
  Actual: `lib/errors.ts` manda `{ error, codigo?, campo?, tipo? }`; NOVA a veces sustituye el motivo por el código HTTP; no hay catálogo de números de error de sistema ni regla explícita para consecutivos.
  Archivos: backned_sistema_gestion_documental/lib/errors.ts y rutas que generan ENT/SAL/INT; NOVA_FT/src/app/lib/sgdApi.ts (errorSgd).
  Evidencia: lib/errors.ts reescrito con el contrato RN-AC-15: errorFormulario (4xx: error, campo, tipo) y errorSistema (5xx: número del catálogo 1000-1011 y motivo; consecutivo solo en 1010/1011; detalle técnico solo fuera de producción); n8n.ts, catalogos.ts, anular, responder-directo y las rutas de transferencias (antes {mensaje}) usan el contrato; caídas de n8n salen como 1004 y webhook sin configurar como 1003. Frontend: sgdApi.mensajeErrorSgd muestra "Error 1001: motivo" o la descripción, y archivoCentralApi lo usa. Pruebas: npm test 14/14 (tests/errores.test.mjs), probar_local.sh con la prueba nueva "la validación fallida no consume consecutivo", tsc backend 0, npm run build OK. En vivo: duplicado 409 con campo nombre, 401 sin token, 404/400 en transferencias, 1002 por la migración 16 pendiente. Catálogo documentado en spec/architecture.md.
  Pendiente: revisión humana; actualizar el contrato en APIs_backend_n8n.md si n8n lee el campo de error

- [ ] SGD-004: Completar las skills del proyecto con project-setup (comandos de lint/test/build del backend y frontend, rama de desarrollo, estructura real)
  Depende de: SGD-001 (P-11, P-12)
  Tipo: chore
  Prioridad: media
  Evidencia: skills desarrollo, testing y git (y tools, workflows, frontend, architecture, README y el ejemplo de project-manager) sin {{PLACEHOLDERS}}: stack con versiones, árbol real de carpetas, convenciones y patrones propios, comandos reales de backend (tsc, lint, npm test, build), BD (probar_local.sh) y frontend (typecheck con línea base 28, vite build), variables de entorno por nombre. Espejo .agents/skills idéntico (diff vacío). Se agregó npm test al backend. Todos los comandos documentados se ejecutaron y pasan.
  Pendiente: quedan dos marcadores de diseño fuera del alcance ({{HOSTING}} en agents/specializations.md y {{TONO_MOVIMIENTO}}), que dependen de P-11 y del diseño; revisión humana
