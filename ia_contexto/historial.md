# Historial — Sistema de Gestión Documental (SGD)

Bitácora cronológica, lo más reciente arriba. Una entrada por cierre, decisión o cambio relevante.

<!-- Formato:
## AAAA-MM-DD — SGD-XXX cerrada | en revisión | decisión | título corto
Cambio: qué se hizo y dónde
Tests: comando ejecutado y resultado (o "no aplica (solo documentación)")
Seguridad: secretos, validaciones, permisos revisados
Commit: hash o "ninguno"
-->

## 2026-10-30 — feature | Historias académicas: título del documento, nivel del catálogo, guardar y buscar
Cambio: la carga masiva de historias (Carga D) deja de ser simulada: cada archivo "Listo" se sube con POST /api/historias (nuevo; permiso cargas.historias, 409 si el archivo ya está en la historia) y fn_historia_cargar (migración 25) crea o reutiliza el estudiante (por cédula, del nombre del archivo) y su historia en el programa, y guarda el documento con su TÍTULO (p. ej. "Acta de grado"), que se escribe en el paso 1 y se puede cambiar por archivo en la vista previa. El nivel y el programa salen del catálogo (Pregrado, Especialización, Maestría, Doctorado según los programas activos). Consulta › Buscar encuentra historias por título, nombre o cédula (alcance "Solo historias académicas" o todo), con historias.consultar y fn_puede_ver_historia (Registro Académico solo activas); abre el documento en modo solo consulta. fn_archivo_buscar también devuelve carro, estante y bandeja. LoteDetalle acepta `procesar` para cargas reales.
Tests: tsc sin errores en archivos propios; API: Secretaría General y Dependencia → 403 al cargar historias; sin título → 400 con campo. La carga completa y la búsqueda de historias no se probaron: falta aplicar la migración 25 en Supabase (Docker apagado: el SQL no se probó en un PostgreSQL limpio).
Pendiente: aplicar migraciones 23, 24 y 25 en Supabase (en ese orden); GET /api/archivos/{id} solo exige sesión y no revisa si el perfil puede ver el recurso (ya estaba así; con historias pesa más por la Ley 1581).
Commit: rama feature/historias-titulo-busqueda.

## 2026-10-30 — feature | Ubicación Carro → Estante → Bandeja → Caja → Carpeta (D-23) y especializaciones de posgrado
Cambio: el componente UbicacionFisica.tsx pasa a cinco campos (Carro, Estante, Bandeja, Caja, Carpeta) en carga de documento, clasificar (Caja y Carpeta obligatorias), detalle, clasificados, archivo y búsqueda; transferencias, acta y catálogo de Ubicaciones usan Carro · Estante · Bandeja. Backend: documentos (crear y clasificar) aceptan carro, estante y bandeja y los devuelven; catálogo de ubicaciones con esos campos. Migración 23: versiona las columnas carro/estante/bandeja que ya existían en Supabase sin migración (documento, inventario_item, transferencia, ubicacion_fisica), bodega opcional, fn_documento_clasificar las guarda y fn_catalogo_columnas las permite. Migración 24: nivel_academico gana especializacion, maestria y doctorado (antes crear una especialización en Catálogos fallaba con "invalid input value for enum"). Historias académicas › carga masiva: el programa sale del catálogo; con Posgrado se listan Especializaciones, Maestrías y Doctorados. Catálogos › Programas: filtro por nivel.
Tests: tsc sin errores en archivos propios (backend y frontend); Vite compila los 14 módulos tocados; API con el login temporal: clasificados devuelven carro/estante/bandeja; en el Supabase real el catálogo aún ignora carro y bandeja y el nivel especializacion no existe hasta aplicar las migraciones 23 y 24 (registro de prueba de ubicación id 3 inactivado).
Pendiente: aplicar en Supabase las migraciones 23 y 24 (SQL Editor); fn_archivo_buscar no devuelve carro/estante/bandeja; no se probó en pantalla.
Commit: rama feature/ubicacion-carro-estante-bandeja.

## 2026-10-29 — feature | Ubicación física con la misma distribución en todo Archivo Central (D-22)
Cambio: NOVA_FT `pages/archivo-central/UbicacionFisica.tsx` (Caja + Carpeta, bloque opcional "Ubicación en bodega" con el catálogo de ubicaciones activas, `textoUbicacion`), usado en Carga de documento, Clasificar (Caja y Carpeta obligatorias), Detalle del documento, Clasificados, Archivo y Búsqueda; Nueva transferencia cambia el texto libre "Depósito 2 · Estante 4" por el selector opcional de bodega (la caja y la carpeta siguen en el FUID); detalle de transferencia y acta muestran "Ubicación en bodega". Backend: `POST /api/documentos` acepta `ubicacion_id`; `lib/clasificados.ts` devuelve `ubicacion` {id, bodega, estante, módulo}.
Tests: tsc sin errores en archivos propios (los 28 que quedan son de código de NOVA, ya estaban); Vite compila los 10 módulos tocados; API: cargar con `ubicacion_id` → 201 con la bodega, clasificados trae `ubicacion` (documento de prueba anulado).
Pendiente: `fn_archivo_buscar` (Archivo y Búsqueda) no devuelve la bodega todavía, solo caja y carpeta; P-08 sigue abierta con el cliente.
Commit: ver ramas feature/ubicacion-fisica-unificada.

## 2026-10-27 — docs | F-05 plan de pruebas para el verificador
Cambio: se armó ia_contexto/spec/acceptance-tests/F-05_plan_pruebas.md con el alcance del backlog ya hecho o en revisión (catálogos, parámetros, plantillas, auditoría, carga A, transferencia física, visor, comunicaciones F1–F3 y anulación). Incluye lo que no se prueba aún (lotes, transferencia digital, clasificar persistente, IA, búsqueda, F4, histórico Excel, historias, PWA), los bugs SGD-087 a 090 y una hoja de resultados. trazabilidad.md apunta a ese F-05.
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-27 — bug | SGD-090 en por realizar (textos de Parámetros)
Cambio: en Catálogos › Parámetros el administrador ve códigos de requisitos (RNF-AC, RF-AC, RN-AC, P-13) porque vienen en parametro.descripcion del seed. El usuario pidió que cada ítem tenga solo una explicación de qué es, sin esa jerga. Quedó como SGD-090; no se cambió código.
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-27 — decisión | D-21 y bugs SGD-087 a SGD-089 en por realizar
Cambio: el usuario dejó como regla el contrato de errores JSON (número + motivo; consecutivo solo en error de sistema; formulario = descripción). Quedó como D-21, RN-AC-15 y sección en architecture.md. En tareas-por-realizar.md se documentaron tres bugs: SGD-087 (crear a mano en Catálogos), SGD-088 (clic en toda la fila/tarjeta para ver el documento en Por clasificar, Clasificados y Archivo) y SGD-089 (implementar el contrato de errores).
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-28 — docs | F-05 v1.1, menú lateral, píldoras de cargas y paginación
Cambio: plan F-05 v1.1 con cómo entrar por el login temporal (perfiles, clave entregada en privado, bloqueo, cambio de perfil) y casos nuevos de permisos por perfil, archivo, búsqueda, histórico, paginación y pantalla; defectos 087–090 pasan a "comprobar que ya no pasan". Frontend: menú lateral de Archivo Central sin barra de desplazamiento (tamaño según el alto de la pantalla) y con el fondo del Panel de Área de NOVA; tipos de carga como píldoras en una línea; paginación en Por clasificar, Clasificados (20) y Últimos lotes (10) con el componente Paginacion.
Tests: revisado en el navegador a 1366×768, 1440×900 y 1920×1000; tsc frontend 28 (línea base).
Pendiente: la paginación corta en el navegador hasta 200 documentos que entrega el backend; paginar en el servidor con SGD-020.

## 2026-10-28 — SGD-032 en revisión | Archivo navegable y búsqueda avanzada
Cambio: migración 20 (árbol con contadores, búsqueda en documentos y comunicaciones con permisos y límite por dependencia); APIs /api/archivo/arbol y /api/archivo/buscar; Archivo con datos reales y paginación; pantalla Buscar habilitada; ComunicacionesArea puede abrir una comunicación por id. /api/clasificados y /api/documentos exigen permiso y limitan Dependencia a lo suyo.
Tests: probar_local.sh todo correcto (16 nuevas); npm test 21/21; tsc backend 0; tsc frontend 28 (línea base); en vivo con el login temporal por perfil.
Seguridad: se cerró que cualquier usuario autenticado listara todos los documentos; intentos sin permiso auditados; los comodines de búsqueda del usuario se tratan como texto.
Pendiente: aplicar en Supabase las migraciones 16, 18, 19 y 20.
Commit: ninguno (pendiente de revisión).

## 2026-10-28 — decisión | Login temporal de pruebas por perfil y cierre de exposiciones
Cambio: login de pruebas en /login-temporal (botón "Login 2"): el usuario elige perfil (Archivo Central, Administrador, Dependencia con su dependencia, Registro Académico, Secretaría General) y la clave que vive solo en el backend; el backend crea los usuarios ficticios @prueba.sgd.test y entrega un token firmado de 8 horas que auth.ts acepta solo en desarrollo. Reemplaza el atajo DEV_BYPASS_AUTH + VITE_SGD_DEV_TOKEN. Remitir y enviar respuesta pasan por el backend (/enviar-remision, /enviar-respuesta) en vez de llamar a n8n desde el navegador. A pedido del usuario, con el login temporal activo la barra de NOVA oculta "Registrarse". Retiro antes del despliegue: SGD-091 e ia_contexto/login-temporal.md.
Tests: tsc backend 0; npm test 14/14; tsc frontend 28 (línea base); vite build OK; backend en vivo: login por perfil, 401 con clave mala o token alterado, 429 tras 5 intentos, 403 según perfil (auditoría, parámetros, catálogos) y 200 donde corresponde; navegador: página, ingreso, sesión en el módulo, salir y barra de navegación.
Seguridad: el build de producción anterior llevaba incrustados el token de desarrollo (archivoCentralApi.ts) y el token de n8n (comunicacionesApi.ts); el nuevo build no contiene ningún secreto ni código del login temporal (revisado buscando los valores en NOVA_FT/dist). Ningún valor estuvo en Git. SGD_DEV_TOKEN rotado; falta rotar N8N_SERVICE_TOKEN en el backend y en n8n.
Commit: ninguno (pendiente de revisión).

## 2026-10-27 — SGD-090 y SGD-044 en revisión | Conjunto 3: parámetros en lenguaje de usuario y registro histórico
Cambio: migración 18 (descripciones de parámetros sin códigos de requisitos) y migración 19 (importación idempotente del Excel histórico, calendario y lista por mes, con permisos y auditoría). Backend lib/historico.ts y rutas /api/comunicaciones/historico, /mes e /importar; rpc de lib/catalogos.ts exportado para reutilizarlo. Frontend: pantalla Registro histórico (antes un aviso "en construcción") y asistente Importar Excel con mapeo de columnas y vista previa. Además, a pedido del usuario: Catálogos › Dependencias ya no muestra ni acepta "Dependencia superior" (la columna sigue en la base).
Tests: probar_local.sh todo correcto (20 pruebas nuevas); tsc backend 0; lint 0 errores; npm test 14/14; npm run build OK; tsc frontend 28 (línea base); navegador: títulos de parámetros, lectura y mapeo de un CSV ficticio, mensajes de error; backend en vivo: 400 con campo, 401 y 1002.
Seguridad: importar exige cargas.historico y consultar comunicaciones.consultar, revisados en la base y auditados si se niegan; Dependencia solo ve el histórico de su dependencia; el Excel se lee en el navegador y solo viajan las columnas mapeadas; errores por fila sin texto interno de PostgreSQL.
Pendiente: aplicar en Supabase las migraciones 16, 18 y 19; confirmar I-18 e I-19 con el cliente.
Commit: ninguno (pendiente de revisión).

## 2026-10-27 — SGD-087, 088, 089 y 004 en revisión | Conjunto 2: bugs de catálogos, filas clicables, contrato de errores y skills
Cambio: contrato de errores RN-AC-15 en lib/errors.ts (catálogo de números de sistema 1000-1011, errorFormulario/errorSistema, columna real del duplicado, n8n caído = 1004) aplicado en n8n.ts, catalogos.ts, anular, responder-directo y transferencias; frontend lee el contrato (sgdApi.mensajeErrorSgd, archivoCentralApi). Filas clicables y con teclado en Por clasificar, Clasificados y Archivo. Registros de prueba de SGD-087 inactivados con motivo. Skills con los comandos y la estructura reales; npm test en el backend.
Tests: npm test 14/14; probar_local.sh todo correcto (prueba nueva: la validación fallida no consume consecutivo); tsc backend 0; npm run build backend OK; tsc frontend 28 (línea base); vite build OK; navegador: filas de las tres pantallas; backend en vivo: 409 duplicado con campo, 401, 404, 400 y 1002.
Seguridad: los errores ya no devuelven el detalle de PostgreSQL ni rutas de archivos; el detalle técnico solo sale fuera de producción. Aviso de Next.js 16.4.0 con una vulnerabilidad conocida (pendiente decidir la actualización).
Pendiente: aplicar en Supabase las migraciones 16 y 17.
Commit: ver git log (subido por pull request).

## 2026-10-27 — SGD-005, 010, 011 y 012 en revisión | Conjunto 1: catálogos, parámetros, plantillas y auditoría
Cambio: migración 17 (fn_catalogo_guardar, fn_catalogo_estado, fn_catalogo_importar, fn_parametro_guardar, fn_plantilla_guardar, fn_auditoria_consultar; el trigger de auditoría guarda el motivo y el id de parámetros y plantillas). Backend: lib/catalogos.ts escribe por esas funciones con el usuario real, filtros en lista blanca y listado de usuarios sin datos personales innecesarios; rutas nuevas /api/catalogos/{tabla}/importar, /api/parametros, /api/plantillas y /api/auditoria; /api/transferencias/resumen exige token. Frontend: Importar Excel con vista previa, inactivar con motivo, pestaña Parámetros, pantallas Plantillas de correo y Auditoría en el menú; sgdApi adjunta campo y tipo al error para marcar el campo del formulario.
Tests: probar_local.sh — todas las migraciones y pruebas pasan (22 nuevas); tsc del backend 0 errores; tsc del frontend 28 (línea base de NOVA, se corrigieron los 2 de CatalogosArea); vite build OK; navegador: catálogos, parámetros, plantillas, auditoría e importación (lectura del Excel); backend: 403 sin permiso, 401 sin token, aviso de migración pendiente.
Seguridad: permisos revisados en la base y auditados cuando se niegan; sin columnas arbitrarias en filtros ni escrituras; el listado de usuarios ya no devuelve cédula, teléfono ni datos de NOVA.
Pendiente: aplicar en Supabase las migraciones 16 y 17.
Commit: ninguno (pendiente de revisión).

## 2026-10-27 — decisión | Tablero ordenado con lo ya realizado
Cambio: se revisó cada tarea del backlog contra el repositorio, las pruebas y n8n. A tareas-en-revision.md pasaron SGD-008, 021, 022, 040, 041 y 042 (implementadas y subidas) y se actualizaron SGD-007 y 080; se agregaron SGD-081 a 086 por trabajo hecho fuera del tablero. A tareas-por-realizar.md pasaron SGD-004, 005, 010, 020, 030, 043 y 044, con su avance y lo que falta. En tareas-faltantes.md quedan las 14 que no se han empezado, con notas donde hay algo adelantado. Ninguna se pasó a tareas-hechas.md: ninguna cumple todavía la definición de terminado (pull request revisado por el compañero, prueba automática y Swagger).
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-12 — fix | Se perdía el texto cuando la dependencia respondía más de una vez
Cambio: n8n_registrar_respuesta_dependencia (migración 09) ponía cada respuesta sobre el último evento «respuesta_dependencia»; con una segunda respuesta (otro correo de la dependencia) el estado ya no cambiaba, no se creaba evento, el adjunto se colgaba del primero y el texto se perdía (caso real: ENT-2026-000029, evento 95 con 2 adjuntos y un solo texto). Migración 15: cada correo de respuesta es su propio evento (con estado_anterior = estado_nuevo y detalle.respuesta_adicional = true si ya estaba respondida), con su remitente, texto y adjuntos; idempotente por Message-ID. No cambia el contrato del backend ni de n8n.
Tests: probar_local.sh pasa con las 17 migraciones (5 pruebas nuevas; las existentes de respuesta/devolución siguen pasando).
Pendiente: aplicar la migración 15 en Supabase. El texto del segundo correo de ENT-2026-000029 no está en la base (sí en la ejecución #20079 de F1 en n8n).
Commit: ninguno.

## 2026-10-12 — feature | Correo adicional a cualquier dependencia
Cambio: el diálogo «Correo adicional» permite elegir el remitente, la dependencia asignada u otra dependencia activa (las que no tienen correo oficial aparecen deshabilitadas). Backend (correo-adicional/route.ts): acepta dependencia_id opcional; valida que exista, esté activa y tenga correo; error claro si la comunicación no tiene dependencia ni remitente con correo. Contrato con F4 y la base sin cambios (destinatario_tipo sigue siendo 'remitente' | 'dependencia').
Tests: tsc sin errores en archivos propios; validaciones probadas en el backend real (dependencia inexistente y tipo inválido → 400, sin llegar a n8n); diálogo revisado en el navegador sin enviar.
Commit: ninguno.

## 2026-10-12 — feature | Ver el correo de cada paso del historial de una comunicación
Cambio: en el detalle, los pasos del historial que envían o reciben correo (recepción, acuse, remisión, respuesta de la dependencia, devolución, recordatorio, respuesta al remitente, correo adicional) se pueden abrir: el correo (De, Para, Fecha, Asunto, cuerpo) y sus adjuntos se muestran en la columna izquierda, en lugar del correo original, con botón «Ver correo original». Base: migración 14 (tabla correo_enviado, inmutable, + n8n_registrar_correo_enviado, idempotente por Message-ID). Backend: POST /api/n8n/correos/enviado (F5 guarda la copia) y GET /api/comunicaciones/{id}/eventos/{eventoId}/correo (usa la copia y, si no hay, lo que ya guardaba la base). F5: nodos «Guardar copia del correo» (On Error → Continue) y «Devolver resultado» en flujos n8n/F5_envio_de_correo (1).json y F5_nodos_copia_correo_PEGAR.json. Frontend: lib/correosEventoApi.ts y DetalleComunicacion.tsx.
Tests: probar_local.sh pasa con las 16 migraciones (6 pruebas nuevas); tsc sin errores en backend y en los archivos propios del frontend; probado en el navegador con ENT-2026-000019 (respuesta de dependencia con adjunto, respuesta al remitente, remisión antigua sin copia → aviso).
Pendiente: aplicar la migración 14 en Supabase y agregar los 2 nodos a F5 en n8n. Los correos enviados antes de eso solo muestran lo que ya estaba guardado.
Commit: ninguno.

## 2026-10-12 — fix | El token de pruebas del backend usaba un usuario inventado (id 1)
Cambio: lib/auth.ts tenía dos caminos para SGD_DEV_TOKEN; el primero (usuarioDesarrollo) devolvía id 1 sin consultar la base, así que "Responder directo" y demás acciones mandaban usuario 1 a Supabase y a n8n. Se quitó: el token de pruebas pasa por validarTokenNOVA y se sincroniza como el usuario 2 (dev@localhost).
Tests: tsc sin errores; consulta de solo lectura confirma dev@localhost = usuario 2 (archivo_central).
Commit: ninguno.

## 2026-10-12 — fix | FK comunicacion_evento_usuario_id_fkey al responder/remitir desde n8n
Causa: el flujo (o una prueba manual del webhook) manda un usuario_id que no existe en `usuario` (en el Supabase real solo existe el usuario de pruebas id=2; la prueba mandaba usuario 1). El INSERT del evento fallaba con la FK sin indicar qué usuario.
Cambio: migración 20261013000000_validar_usuario_actual.sql — fn_set_usuario_actual valida que el usuario exista y lanza «[campo:usuario|tipo:existente] El usuario N no existe…» (22023 → 400 claro en el backend); null sigue permitido. Cubre todas las funciones n8n_* y *_usuario.
Tests: probar_local.sh — 15 migraciones, 5 pruebas nuevas OK (usuario inexistente no cambia el estado). 
Pendiente del usuario: ejecutar la migración 13 en Supabase y usar usuario_id = 2 en pruebas manuales de los webhooks de F2/F3.
Commit: ninguno.

## 2026-10-12 — fix | Responder directamente al remitente (botón "Responder correo")
Síntoma: "Los datos enviados no son válidos. Revise el formulario." al responder directo desde la Bandeja.
Causas: (1) al Supabase real le faltaba la migración 11 → no existe fn_responder_directo (PGRST202); (2) aun con la migración 11, el trigger de estados rechazaba nueva → respondida_dependencia (RN-AC-09): la "excepción" estaba documentada pero nunca implementada; (3) NOVA reemplaza el motivo real del backend por un texto genérico por código HTTP.
Cambio: migración 20261012000000_responder_directo_transicion.sql (excepción solo dentro de fn_responder_directo mediante bandera local app.responder_directo; un único evento en el historial; ENT en nueva/remitida/devuelta/respondida); responder-directo/route.ts (valida el webhook antes de tocar la BD, 502 si n8n falla con reintento seguro, 409 para reglas de negocio, mensaje claro si falta la migración); sgdApi.ts (errorSgd: el motivo real llega a la pantalla); .env.example documenta N8N_WEBHOOK_*.
Tests: probar_local.sh — 14 migraciones, 8 pruebas nuevas OK (incluye que otro UPDATE directo sigue bloqueado y el flujo directo + F3 cierra con SAL); backend tsc/eslint OK; navegador: el toast ahora muestra el motivo real.
Pendiente del usuario: ejecutar en Supabase 20261011000000_f4_manual_y_correo_adicional.sql y 20261012000000_responder_directo_transicion.sql.
Commit: ninguno.

## 2026-10-08 — Frontend · Visor de adjuntos para todos los formatos + rediseño de Archivo Central
Cambio: VisorArchivos reescrito: PDF con react-pdf (páginas, zoom, ajuste al ancho, rotación; funciona en celular), Word .docx con docx-preview (ajuste al ancho, zoom; sin recorte del borde izquierdo), Excel .xlsx con exceljs (pestañas por hoja), texto/CSV/JSON/.eml, imágenes con zoom/rotación; aviso + descarga para formatos sin vista previa. Nueva dependencia docx-preview 0.4.1 (Apache-2.0). lib/pdfWorker.ts: worker del paquete en desarrollo, /pdf.worker.min.mjs en producción (como AreaDashboard). ArchivoCentralArea: sin segundo encabezado (el navbar de NOVA muestra "Archivo Central" bajo el usuario), menú lateral más grande y legible, fijo al hacer scroll y terminando en el footer, panel deslizable en celular, Correos sin asociar y Registro histórico conectados a Comunicaciones, sin contadores falsos, "Pronto" en secciones sin construir. Visor de vuelta en la columna izquierda (pedido del usuario). Pestañas y filtros de la Bandeja más grandes.
Tests: tsc sin errores; navegador contra backend real: 2 PDF, 1 .docx (2 páginas, cabe completo) y 1 .txt se ven; celular 375 px sin desbordamiento, menú en panel, PDF ajustado.
Observación: hay un botón/ruta "Eliminar definitivamente" (DELETE /api/comunicaciones/{id}/eliminar) marcado como solo pruebas pero sin restricción de entorno → choca con RN-AC-12 en producción.
Commit: ninguno.

## 2026-10-08 — Frontend · Detalle de comunicación a pantalla completa + token de pruebas
Cambio: DetalleComunicacion pasa de panel lateral a vista de página como el mockup (volver, encabezado con acciones Remitir/Devolver/Enviar respuesta/Anular, línea de pasos con fechas, correo original, datos, historial legible); nuevo VisorArchivos (lista de adjuntos + vista previa PDF/imagen, Abrir, Descargar, Ampliar) que descarga por id con sgdFetchBlob. Token de pruebas SOLO desarrollo: frontend envía VITE_SGD_DEV_TOKEN con el atajo sin login; backend lo acepta en next dev (SGD_DEV_TOKEN) como usuario de prueba Archivo Central.
Tests: tsc sin errores; probado en navegador contra el backend real (localhost:5173/archivo-central → 3 comunicaciones de Supabase, PDF real en el visor, pantalla completa, historial). Hallazgo: F1 registró "Workflow does not exist" al enviar el acuse → falta poner el ID de F5 en los flujos.
Commit: ninguno.

## 2026-10-07 — revisión | F5 · Envío de correo
Resultado: F5 sin referencias ni conexiones rotas; su entrada/salida coincide con lo que mandan y leen F1–F4 (ok, message_id, contexto) y descarga adjuntos con GET /api/archivos/{id} (acepta el token de n8n).
Corregido: (1) plantillas remision/devolucion no mostraban {mensaje} y devolucion usaba {plazo} vacío; recordatorio usaba {respuesta} y F4 envía {pendientes} → migración 20261007001000_plantillas_variables_n8n.sql (solo plantillas sin personalizar) + seed.sql; (2) GET /api/archivos/{id}: Content-Disposition con filename*=UTF-8'' para que el adjunto no llegue como "Certificado%20de%20notas.pdf".
Tests: probar_local.sh OK (4 pruebas nuevas de plantillas); backend tsc/eslint OK.
Commit: ninguno.

## 2026-10-07 — revisión | Flujos n8n (flujos n8n/*_api.json) contra el backend
Resultado: las 23 llamadas HTTP de F1, F2, F3, F4 y F6 coinciden con las rutas del backend (URL, campos del cuerpo y campos que leen los nodos de código); sin referencias ni conexiones rotas. Corregido lib/errors.ts: handleError respondía 500 en vez de 413/415/404, lo que hacía que F1 reintentara para siempre un correo con un adjunto grande o de formato no permitido.
Pendiente (no corregido): el frontend remite/devuelve/responde llamando a /api/comunicaciones/{id}/... del backend, que solo cambia el estado en la BD y no envía correo; los webhooks de n8n F2 (bandeja/remitir) y F3 (bandeja/responder) no los llama nadie. Falta F5 en la carpeta. Placeholders BACKEND_URL_AQUI, REEMPLAZAR_ID_F5 y credenciales REEMPLAZAR.
Tests: tsc OK; prueba directa de handleError (413/415/404/500).
Commit: ninguno.

## 2026-10-07 — decisión | 19 APIs del backend para los flujos n8n
Cambio: migración 20261007000900_n8n_funciones.sql (8 funciones de n8n_funciones_supabase.sql revisadas + 11 nuevas para F2, F3, F4 y compartidas); backend: lib/n8n.ts (fábrica rutaN8N, lectores de campos, mapeo de errores PG→HTTP) y 19 rutas en app/api/n8n/**; contrato copiado a database/n8n/APIs_backend_n8n.md. D-19.
Correcciones al SQL original: reintento de correo nuevo duplicaba la nota de adjuntos omitidos; la respuesta de dependencia no guardaba su Message-ID (no se detectaba reproceso); permisos fallaban sin rol service_role. probar_local.sh ahora muestra el error si fallan las pruebas.
Tests: probar_local.sh ×3 — 9 migraciones, todas las pruebas OK (24 nuevas de funciones n8n) + concurrencia 40/40; backend tsc/eslint OK; next dev: 19 rutas → 401 sin token, 400 con datos inválidos, llegan a Supabase con datos válidos. Llamada real a Supabase no probada (sin credenciales).
Commit: ninguno.

## 2026-10-07 — decisión | Endpoint para que n8n cree comunicaciones
Cambio: backend Next.js → app/api/n8n/comunicaciones/route.ts (POST, token N8N_SERVICE_TOKEN, validación, 201 creada / 200 ya existía) y esServicioN8N() en lib/auth.ts; BD → migración 20261007000800_n8n_registrar_comunicacion.sql (comunicación + adjuntos en una transacción, idempotente, EXECUTE solo para service_role). TABLAS_N8N.md rama C actualizada. D-18.
Tests: database/scripts/probar_local.sh — 8 migraciones, todas las pruebas OK (5 nuevas de n8n) + concurrencia 40/40; backend tsc y eslint sin errores; next dev: 401 sin token/token malo, 400 JSON y datos inválidos. Registro real contra Supabase no probado (sin credenciales).
Seguridad: comparación del token en tiempo constante; sin secretos en el repo.
Commit: ninguno.

## 2026-10-07 — SGD-080 en revisión | Frontend del módulo Comunicaciones
Cambio: nuevo módulo "Comunicaciones" en el Panel de Área de NOVA (barra lateral + barra móvil), con Bandeja (pestañas por estado incl. Devuelta, filtros, alerta de remitidas ≥5 días), detalle con línea de pasos/historial y acciones Remitir, Devolver, Enviar respuesta y Anular; Correos sin asociar; Registro histórico por mes. Datos simulados en lib/comunicacionesApi.ts con las mismas reglas de estado que la BD. Decisiones D-16 (dentro de NOVA) y D-17 (colores de NOVA).
Tests: tsc sin errores en el módulo; verificación manual en navegador (escritorio y móvil). Corregido: el diálogo de acción cerraba el panel de detalle; fecha límite desfasada por zona horaria.
Seguridad: sin secretos; datos de ejemplo ficticios.
Commit: ninguno.

## 2026-10-07 — decisión | n8n limitado a la Bandeja de comunicaciones
Cambio: D-15 e I-17; TABLAS_N8N.md reescrito solo con F1–F6 (correo entrante, remitir, responder, recordatorios, envío, errores) y subida de adjuntos al backend; F7–F11 pasan al backend (architecture.md, README del backend).
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-07 — decisión | n8n: archivos por el backend, tablas directo en Supabase
Cambio: TABLAS_N8N.md con sección de arquitectura de dos destinos y contrato de POST/GET /api/archivos (token de servicio de n8n, validación, respuesta, errores); D-03 precisado. Agregar el endpoint al backend cuando se decida P-11.
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-07 — SGD-007 en revisión | Base de datos del módulo
Cambio: backned_sistema_gestion_documental/supabase/ con 6 migraciones (catálogos, usuarios sincronizados desde NOVA sin login, archivos por id, lotes, transferencias con regla año − 2, documentos con anti-duplicados, comunicaciones con consecutivos atómicos y máquina de estados, historias, auditoría inmutable, permisos, RLS y vistas), seed.sql, seed_demo.sql, tests y script de prueba. Decisiones D-13 (sin login, token de NOVA) y D-14; preguntas P-16 (actualizada) y P-19.
Tests: scripts/probar_local.sh — 79 verificaciones OK + concurrencia 40/40.
Seguridad: sin secretos; RLS activo y anon/authenticated revocados; sin DELETE; auditoría append-only; datos demo ficticios.
Commit: ninguno.

## 2026-10-07 — decisión | Mockups de escritorio y móvil como referencia
Cambio: agregado ia_contexto/diseno/mockups_archivo_central_y_movil.html (14 pantallas de escritorio + 3 móviles) y su descripción en diseno/README.md; diferencias con el F-02 registradas como I-08…I-16 y preguntas P-17, P-18; enlazado desde spec/product.md, CLAUDE.md y skill frontend.
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-07 — decisión | Archivos locales en carpetas referenciados por id
Cambio: D-02, D-03, RN-AC-14, architecture.md (nueva sección "Almacenamiento de archivos", tabla `archivo`), requirements RF-AC-008, CLAUDE.md/AGENTS.md y skills: los archivos se guardan localmente en carpetas y la BD los referencia por id (`archivo_id`). Registrada I-07 contra el F-02.
Tests: no aplica (solo documentación).
Commit: ninguno.

## 2026-10-07 — decisión | Contexto del módulo Archivo Central desde el F-02 v1.1
Cambio: copiado F-02_Archivo_Central_v1.1.docx (+ extracción .md) a fuentes/; llenados spec/product.md, requirements.md (RF-AC-001…024 con criterios Dado/Cuando/Entonces, RNF-AC-01…10), business-rules.md (RN-AC-01…14 + transiciones de estado), architecture.md (nuevo), decisiones.md (D-01…D-12, P-01…P-16, I-01…I-06), trazabilidad.md, historias/archivo-central.md; backlog SGD-000…SGD-070 en tareas-faltantes.md; skills (contexto, desarrollo, seguridad, testing, memoria) y CLAUDE.md/AGENTS.md con reglas de dominio.
Tests: no aplica (solo documentación).
Seguridad: sin secretos ni datos personales reales.
Commit: ninguno.

## 2026-10-07 — Inicialización del contexto del proyecto
Cambio: creada ia_contexto/ desde las plantillas de la skill project-manager.
Tests: no aplica (solo documentación).
Commit: ninguno.
