# Tareas hechas — Sistema de Gestión Documental (SGD)

> Completadas y verificadas, con nota de cierre (fecha, pruebas, commit).

- [x] SGD-005: Esquema de base de datos
  Spec: ia_contexto/spec/requirements.md#rf-003
  Evidencia: scripts sin errores; pruebas 26/26 OK
  Pendiente: ejecutarlo en el entorno de producción

- [x] SGD-007: Esquema de base de datos en Supabase: tablas, restricciones únicas (hash, Message-ID, asunto por dependencia), RLS y función atómica de consecutivos ENT/SAL/INT con reinicio anual (RN-AC-08) + pruebas de concurrencia
  Spec: ia_contexto/spec/architecture.md#entidades-principales
  Tipo: feature
  Prioridad: alta
  Depende de: SGD-001 (P-10, P-11)
  Evidencia: database/scripts/probar_local.sh en PostgreSQL 18 temporal — todas las migraciones del repositorio (01 a 16) pasan, seeds idempotentes y pruebas_reglas.sql sin fallos (consecutivos concurrentes sin repetir). database/scripts/verificar_supabase.mjs al 15 oct: todo aplicado en el Supabase real salvo la migración 16. Commits e6e7d87, f6c364f.
  Pendiente: confirmar que la migración 16 esté aplicada; la función registrar_transferencia existe en Supabase pero no en las migraciones (agregarla); revisión humana; validar supuestos P-09, P-10, P-15, P-17, P-18.

- [x] SGD-008: Estructura del backend y frontend del módulo, autenticación y servicio de archivos locales en carpetas, tabla `archivo` con id de referencia (SHA-256, descarga autenticada por id), endpoints `POST/GET /api/archivos` para n8n con token de servicio (contrato en backned_sistema_gestion_documental/n8n/TABLAS_N8N.md) (RN-AC-14, RNF-AC-02)
  Tipo: feature
  Prioridad: alta
  Depende de: SGD-001 (P-11, P-12, P-16)
  Evidencia: POST/GET /api/archivos con huella SHA-256 y respuestas 413/415; autenticación con el token de NOVA (token de pruebas solo con next dev) y token de servicio para n8n; errores con campo y motivo; 404 claro si el archivo no está en el equipo. tsc del backend sin errores. Commit 301c181.
  Pendiente: pruebas automáticas del backend y documentación Swagger (definición de terminado, bitácora 2.2); revisión humana; cada integrante guarda los archivos en su propio equipo (se resuelve con un backend compartido)

- [x] SGD-080: Frontend del módulo Comunicaciones en el Panel de Área de NOVA — Bandeja, detalle con Remitir/Devolver/Responder/Anular, Correos sin asociar y Registro histórico (HU-AC-10 a HU-AC-14, RF-AC-015 a 019)
  Spec: ia_contexto/spec/requirements.md#rf-ac-015
  Tipo: feature
  Archivos: NOVA_FT/src/app/pages/comunicaciones/*, NOVA_FT/src/app/lib/comunicacionesApi.ts y sgdApi.ts
  Evidencia: conectado al backend SGD; tsc sin errores en los archivos del módulo; probado en navegador: bandeja por estados, detalle a pantalla completa con visor de adjuntos (PDF, Word, Excel, imágenes), remitir, responder, responder directo, correo adicional, recordatorio manual, anular y ver el correo de cada paso del historial. Commits e091e80, d760477, 74d3012, cf3e397.
  Pendiente: plantillas de correo editables (SGD-012); Remitir y Enviar respuesta aún llaman a n8n desde el navegador con el token público (pasarlos por el backend); revisión humana.

- [x] SGD-040: Recepción automática de correos — flujo F1, Message-ID, consecutivo ENT, acuse de recibo, bandeja por estados (HU-AC-10, RF-AC-015) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-015
  Prioridad: alta
  Depende de: SGD-007, SGD-012, SGD-001 (P-01, P-02)
  Evidencia: F1 registra cada correo con su consecutivo ENT sin duplicar por Message-ID, sube los adjuntos al backend y manda el acuse de recibo por F5; ejecuciones exitosas en n8n. Commits 32579dc, 301c181.
  Pendiente: activar F1 (hoy está inactivo y se corre a mano); importar F6 (errores); pruebas automáticas; revisión humana

- [x] SGD-041: Remitir a dependencia (F2) y registrar su respuesta (F1, etiqueta / In-Reply-To), devolver (HU-AC-11, RF-AC-016) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-016
  Prioridad: alta
  Depende de: SGD-040
  Evidencia: F2 v3 remite y devuelve con la etiqueta [SGD consecutivo] y plazo en días hábiles; F1 asocia la respuesta de la dependencia y guarda cada correo de respuesta como su propio evento, con su texto y adjuntos (migración 15). Commits 32579dc, f6c364f.
  Pendiente: pegar en F2 v3 los nodos que guardan la copia del correo (flujos n8n/F2v3_nodos_copia_correo_PEGAR.json); quitar la dirección de prueba fija en Gmail; revisión humana

- [x] SGD-042: Responder al remitente (F3), crear SAL enlazada y cerrar (HU-AC-12, RF-AC-017) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-017
  Prioridad: alta
  Depende de: SGD-041
  Evidencia: F3 envía la respuesta, crea la comunicación SAL enlazada y cierra la entrada; incluye responder directo sin dependencia (migración 12). Commits 301c181, f6c364f.
  Pendiente: F3 registra siempre al usuario 2 en lugar del que respondió; el frontend manda adjuntos_ids y F3 lee archivo_ids; revisión humana

- [x] SGD-022: Transferencia física: lectura del FUID (F7), inventario por caja, regla año − 2, estado "recibida" (HU-AC-06, RF-AC-009) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-009
  Prioridad: alta
  Depende de: SGD-020, SGD-001 (P-04)
  Evidencia: Pantallas Transferencias (lista, asistente, detalle con inventario) y backend /api/transferencias que registra la transferencia con su inventario FUID leído del Excel; resumen con la regla año − 2. Commits 0122bb2, e906c21.
  Pendiente: la función registrar_transferencia existe en Supabase pero no en las migraciones; GET /api/transferencias/resumen no valida al usuario; confirmar el estado «recibida» y la validación de fechas; revisión humana

- [x] SGD-081: Responder directamente al remitente sin remitir a una dependencia (D-20) y validar que el usuario que actúa exista
  Spec: ia_contexto/spec/decisiones.md#decisiones
  Tipo: feature
  Evidencia: migraciones 12 (excepción nueva → respondida_dependencia solo dentro de fn_responder_directo) y 13 (fn_set_usuario_actual valida el usuario) con pruebas en pruebas_reglas.sql; POST /api/comunicaciones/{id}/responder-directo. Commits f6c364f, 980dd6f.
  Pendiente: revisión humana

- [x] SGD-082: Copia de cada correo enviado y ver el correo de cada paso del historial de una comunicación
  Spec: ia_contexto/spec/requirements.md#rf-ac-015
  Tipo: feature
  Evidencia: migración 14 (tabla correo_enviado inmutable, idempotente por Message-ID); POST /api/n8n/correos/enviado y GET /api/comunicaciones/{id}/eventos/{eventoId}/correo; en el detalle, los pasos con correo se abren con su texto y adjuntos. Commits f6c364f, 980dd6f, 733e19b, cf3e397.
  Pendiente: pegar los nodos de copia en F5 y F2 v3 (flujos n8n/F5_nodos_copia_correo_PEGAR.json); los correos enviados antes de la migración no tienen copia; revisión humana

- [x] SGD-083: Correo adicional a cualquier dependencia activa y varias respuestas de una misma dependencia sin perder ninguna
  Spec: ia_contexto/spec/requirements.md#rf-ac-016
  Tipo: feature
  Evidencia: migración 15 (cada correo de respuesta es su propio evento, idempotente por Message-ID) con 5 pruebas nuevas; POST /api/comunicaciones/{id}/correo-adicional acepta dependencia_id. Commits f6c364f, 980dd6f, cf3e397.
  Pendiente: revisión humana

- [x] SGD-084: Anular un documento del archivo con motivo, sin borrarlo y con auditoría (RF-AC-024)
  Spec: ia_contexto/spec/requirements.md#rf-ac-024
  Tipo: feature
  Evidencia: migración 16 (fn_anular_documento_usuario) con 6 pruebas nuevas en pruebas_reglas.sql; POST /api/documentos/{id}/anular (solo Archivo Central y Administrador); el botón «Anular documento» pide el motivo y llama al backend. tsc sin errores.
  Pendiente: aplicar la migración 16 en Supabase; subir por pull request (hoy solo está en el equipo local); revisión humana

- [x] SGD-085: Visor común de documentos (PDF, imagen y otros formatos) en Clasificados y Por clasificar, con aviso claro cuando el archivo no está en el servidor
  Spec: ia_contexto/spec/requirements.md#rf-ac-011
  Tipo: feature
  Archivos: NOVA_FT/src/app/pages/archivo-central/VisorDocumento.tsx, DetalleDocumento.tsx, ClasificarDocumento.tsx, PorClasificar.tsx; backend app/api/archivos/[id]/route.ts
  Evidencia: probado en navegador con un PDF y una imagen: se ven con su tipo real; sin archivo, el backend responde 404 con mensaje claro en vez de 500 con la ruta del disco. tsc sin errores nuevos.
  Pendiente: subir por pull request (hoy solo está en el equipo local); revisión humana

- [x] SGD-030: Bandejas Por clasificar / Clasificados con visor PDF + formulario, propuesta de TRD y reclasificación auditada (HU-AC-08, RF-AC-011) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-011
  Prioridad: alta
  Depende de: SGD-021
  Avance: listas reales de Por clasificar y Clasificados con el visor del documento
  Falta: guardar la clasificación (hoy el botón Clasificar no persiste); propuesta de TRD; reclasificación auditada

- [x] SGD-000: Obtener la firma del F-02 v1.1 por el cliente (numeral 9) — requisito para iniciar construcción
  Spec: ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx
  Tipo: docs
  Prioridad: alta
  Bloqueo: depende del cliente

- [x] SGD-001: Resolver las preguntas abiertas P-01 a P-16 de spec/decisiones.md (prioridad: P-01, P-02, P-11, P-12, P-16)
  Spec: ia_contexto/spec/decisiones.md
  Tipo: docs
  Prioridad: alta
  Nota: P-11 ya se decidió en la práctica (backend en Next.js con Supabase); falta registrarlo en spec/decisiones.md

- [x] SGD-002: Validar con la jefatura los mockups (ia_contexto/diseno/mockups_archivo_central_y_movil.html) y resolver las diferencias I-08 a I-16
  Spec: ia_contexto/spec/product.md#pantallas-validar-maquetas-antes-de-desarrollar
  Tipo: docs
  Prioridad: alta

- [x] SGD-003: Copiar a ia_contexto/fuentes/ el doc "Flujos n8n — Archivo Central", los SQL y JSON de n8n existentes y el F-03; actualizar spec/architecture.md
  Tipo: docs
  Prioridad: media
  Nota: ia_contexto/fuentes/ solo tiene el F-02; faltan «Flujos n8n — Archivo Central», los SQL/JSON de n8n y el F-03

- [x] SGD-006: Alinear NOVA_FT/src/styles/theme.css a la paleta institucional (I-04)
  Spec: .claude/skills/frontend/color-palette.md
  Tipo: refactor
  Prioridad: media
  Nota: D-17 manda usar los colores de NOVA dentro de NOVA; probablemente se descarta. Confirmar con el equipo

- [x] SGD-021: Carga de documento individual con hash y detección de duplicados — flujo F8 (HU-AC-05, RF-AC-008) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-008
  Prioridad: alta
  Depende de: SGD-020, SGD-010
  Evidencia: La carga A sube el archivo a POST /api/documentos con SHA-256, detecta el duplicado en el mismo expediente (409) y lo deja «por clasificar»; probada en navegador. Commits 1ec2e3a, e906c21.
  Pendiente: pruebas automáticas; revisión humana

- [x] SGD-086: Alertas de estado (Sileo) en el Centro de cargas: procesando, resumen final, pausa y fin del lote
  Spec: ia_contexto/diseno/README.md
  Tipo: feature
  Archivos: NOVA_FT/src/app/lib/alertasCarga.ts y las pantallas de carga y del lote
  Evidencia: probado en navegador con respuestas simuladas del backend: éxito, duplicado, error, pausa y fin del lote; el avisador se dibuja en el body porque AreaDashboard atrapa los elementos fijos. tsc sin errores nuevos.
  Pendiente: subir por pull request (hoy solo está en el equipo local); revisión humana

- [x] SGD-010: Dependencias, TRD y asuntos por dependencia con importación Excel e inactivación (HU-AC-01, RF-AC-001, 002, 003) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-001
  Prioridad: alta
  Depende de: SGD-005
  Relacionado: SGD-087 (bug: crear a mano falla)
  Evidencia: Catálogos › Dependencias, TRD y Asuntos: crear y editar con el usuario real; inactivar exige motivo (queda en la auditoría) y nunca se borra; el campo repetido (código o correo) se marca en el formulario; Importar Excel para dependencias y TRD con vista previa de errores por fila (código repetido, superior inexistente, correo de otra dependencia) y confirmación que solo inserta las válidas (POST /api/catalogos/{tabla}/importar). migración 17 (20261017000000_catalogos_parametros_auditoria.sql) con 22 pruebas nuevas en pruebas_reglas.sql: todas pasan con database/scripts/probar_local.sh; lectura del Excel probada en navegador (encabezados con tildes y CSV UTF-8).
  Pendiente: aplicar la migración 17 en Supabase y probar una importación real; subir por pull request; revisión humana

- [x] SGD-012: Usuarios y perfiles, parámetros y plantillas de correo con vista previa (HU-AC-03, RF-AC-005, 006) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-005
  Prioridad: alta
  Depende de: SGD-005
  Evidencia: Catálogos › Usuarios: el Administrador asigna perfil y dependencia (los usuarios no se crean aquí: llegan desde NOVA) y el listado ya no expone cédula, teléfono ni datos crudos de NOVA; Catálogos › Parámetros con validación de tipo y rango en la base (solo Administrador); Administración › Plantillas de correo con variables, vista previa con datos de ejemplo, confirmación viendo la vista previa antes de guardar y restablecer el texto original. migración 17 (20261017000000_catalogos_parametros_auditoria.sql) con 22 pruebas nuevas en pruebas_reglas.sql: todas pasan con database/scripts/probar_local.sh.
  Pendiente: aplicar la migración 17 en Supabase; revisión humana

- [x] SGD-087: [BUG] Catálogos: falla al crear un registro de forma manual
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

- [x] SGD-088: [BUG] Por clasificar, Clasificados y Archivo: la fila/tarjeta no abre la previsualización; solo el botón
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

- [x] SGD-089: [BUG] Respuestas de error: JSON con número y motivo; consecutivo solo en error de sistema; formulario = descripción
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

- [x] SGD-004: Completar las skills del proyecto con project-setup (comandos de lint/test/build del backend y frontend, rama de desarrollo, estructura real)
  Depende de: SGD-001 (P-11, P-12)
  Tipo: chore
  Prioridad: media
  Evidencia: skills desarrollo, testing y git (y tools, workflows, frontend, architecture, README y el ejemplo de project-manager) sin {{PLACEHOLDERS}}: stack con versiones, árbol real de carpetas, convenciones y patrones propios, comandos reales de backend (tsc, lint, npm test, build), BD (probar_local.sh) y frontend (typecheck con línea base 28, vite build), variables de entorno por nombre. Espejo .agents/skills idéntico (diff vacío). Se agregó npm test al backend. Todos los comandos documentados se ejecutaron y pasan.
  Pendiente: quedan dos marcadores de diseño fuera del alcance ({{HOSTING}} en agents/specializations.md y {{TONO_MOVIMIENTO}}), que dependen de P-11 y del diseño; revisión humana
