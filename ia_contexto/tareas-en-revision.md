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

- [ ] SGD-090: [BUG] Parámetros: las descripciones en pantalla citan códigos de requisitos (RNF, RF, RN)
  Tipo: bug
  Prioridad: media
  Etiquetas: bug, parametros, ux
  Skills: desarrollo
  Relacionado: SGD-012
  Pasos para reproducir: 1. Abrir Archivo Central › Catálogos › Parámetros. 2. Leer el texto de cada valor (es el campo descripcion de la base).
  Esperado: cada parámetro se explica en lenguaje de usuario (qué hace y para qué sirve). Sin códigos RNF-AC, RF-AC, RN-AC, P-xx ni jerga de documentos de requisitos.
  Actual: el seed pone textos como «RNF-AC-08: tamaño máximo…», «RF-AC-016: plazo…», «RN-AC-03: años en archivo…», «RF-AC-012: … (P-13)». ParametrosPanel.tsx muestra esa descripcion como título.
  Archivos: database/supabase/seed.sql (y una migración que actualice descripcion en bases ya sembradas); NOVA_FT/src/app/pages/archivo-central/ParametrosPanel.tsx si hay textos fijos.
  Evidencia: migración 18 (20261018000000_parametros_descripcion_usuario.sql) reescribe las 9 descripciones en lenguaje de usuario sin tocar los valores; seed.sql con los mismos textos; Parámetros muestra un título corto por parámetro y la descripción como ayuda (ya no la clave técnica). Prueba nueva en pruebas_reglas.sql: ninguna descripción cita RF/RN/RNF-AC, P-xx, mockup ni tentativo. verificar_supabase.mjs revisa el contenido y hoy marca la migración 18 como pendiente. Navegador: títulos cortos visibles. tsc del frontend 28 (línea base).
  Pendiente: aplicar la migración 18 en Supabase; revisión humana

- [ ] SGD-044: Histórico de comunicaciones en calendario e importación idempotente de Excel 2024/2025/2026 (F10) (HU-AC-14, RF-AC-019) · 5 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-019
  Prioridad: alta
  Depende de: SGD-007
  Evidencia: migración 19 (20261019000000_historico_comunicaciones.sql): fn_historico_importar (vista previa o confirmación; comunicaciones cerradas con consecutivo TIPO-AAAA-9NNNNN y número original conservado; idempotente; número repetido en el mismo año y archivo se reporta para revisión; dependencia por código o nombre con aviso si no existe; auditoría con usuario), fn_historico_calendario y fn_historico_mes (Dependencia solo ve lo suyo). APIs GET /api/comunicaciones/historico, GET /api/comunicaciones/historico/mes y POST /api/comunicaciones/historico/importar. Pantalla Registro histórico: año, filtro Todas/Recibidas/Enviadas/Internas, calendario de 12 meses (total, cerradas en el sistema, importadas de Excel, "Aún no llega"), lista del mes con apertura del detalle; asistente Importar Excel con hoja, detección de la fila de encabezados, mapeo de columnas, tipo para todas las filas, vista previa, confirmación y descarga del resultado. Pruebas: 18 nuevas en pruebas_reglas.sql (probar_local.sh todo correcto), tsc backend 0, lint 0 errores, npm test 14/14, npm run build OK, tsc frontend 28. Navegador: CSV ficticio con título encima, separador ; y fechas DD/MM/AAAA leído y mapeado solo; backend en vivo: 400 con campo en datos inválidos, 401 sin token y 1002 porque falta la migración.
  Pendiente: aplicar la migración 19 en Supabase y probar con un Excel real cuando el cliente lo entregue; confirmar I-18 (¿Secretaría General importa?) e I-19 (formato del consecutivo histórico); registrar la importación como lote del Centro de cargas cuando exista (SGD-020); revisión humana

- [ ] SGD-032: Árbol Dependencia → Año → Asunto con contadores y búsqueda avanzada paginada (HU-AC-09, RF-AC-013, 014) · 8 pts
  Spec: ia_contexto/spec/requirements.md#rf-ac-013
  Prioridad: alta
  Depende de: SGD-030
  Evidencia: migración 20 (20261020000000_archivo_busqueda.sql): fn_archivo_arbol (árbol Dependencia → Año → Asunto con contadores, incluye dependencias sin documentos), fn_archivo_buscar (documentos clasificados + comunicaciones, 20 por página, filtros año, mes, día, dependencia, tipo, asunto, consecutivo, persona, TRD, texto; comodines del usuario escapados), fn_alcance_consulta (permiso auditado y límite por dependencia); índices trigram de destinatario. Backend: GET /api/archivo/arbol y /api/archivo/buscar; "385 del 29 de febrero" se interpreta en lib/consecutivoTexto.ts (7 pruebas unitarias). /api/clasificados y /api/documentos ahora exigen documentos.consultar o documentos.clasificar y limitan Dependencia a lo suyo (antes cualquier usuario veía todo). Frontend: Archivo con datos reales (antes datos de ejemplo escritos en el código), paginación y visor; Buscar habilitado en el menú, abre documentos en el visor y comunicaciones en su detalle. Pruebas: 16 nuevas en pruebas_reglas.sql (probar_local.sh todo correcto), npm test 21/21, tsc backend 0, tsc frontend 28 (línea base); en vivo con el login temporal: Registro Académico 403 en Clasificados, Dependencia 403 en Por clasificar, Archivo Central 200; Archivo y Buscar muestran el aviso 1002 mientras falte la migración.
  Pendiente: aplicar la migración 20 en Supabase y probar árbol y búsqueda con datos reales; P-09 (qué perfiles descargan) sigue abierta: la descarga no cambia; revisión humana

- [ ] SGD-091: Quitar el login temporal de pruebas por perfil (/login-temporal) y dejar solo el token de NOVA
  Tipo: chore
  Prioridad: alta (bloquea el despliegue)
  Etiquetas: seguridad, despliegue
  Skills: seguridad, desarrollo
  Requisito: regla 10 de CLAUDE.md (sin login propio), D-13
  Pasos: seguir la lista de ia_contexto/login-temporal.md (todo está marcado con ⚠️ TEMPORAL), quitar las variables de los .env y comprobar que el build de producción no contiene login-temporal ni sgdtmp.
  Nota: rotar N8N_SERVICE_TOKEN (también en la credencial de n8n): estuvo en un build local del frontend antes del 2026-10-28.
  Evidencia: backend sin lib/loginTemporal.ts ni /api/login-temporal (404 en el build de producción); frontend sin lib/loginTemporal.ts, pages/login-temporal, LOGIN_TEMPORAL ni el botón Login 2; AuthContext.tsx e InstitutionalNavbar.tsx vuelven a su versión de NOVA; la app móvil usa la sesión de NOVA. Build de producción del frontend sin login-temporal, sgdtmp ni tokens.
  Pendiente: revisión humana; inactivar con motivo los usuarios @prueba.sgd.test en la base de producción si se migran datos; rotar N8N_SERVICE_TOKEN

- [ ] SGD-093: Auditoría para Archivo Central (D-28), Comunicaciones oculta en el menú y acceso desde el celular
  Tipo: feature
  Evidencia: migración 30 (permiso auditoria.consultar para archivo_central), seed, prueba y verificar_supabase; flag oculto en Bandeja y Correos sin asociar; Vite con --host en .claude/launch.json (el backend ya aceptaba la red local en desarrollo). Pruebas D-28 en pruebas_reglas.sql; vista de celular por 192.168.1.2 revisada en el navegador.
  Pendiente: aplicar la migración 30 en Supabase; revisión humana

- [ ] SGD-094: Preparar el despliegue: base de datos local, Docker, rama solo backend, acceso por rol área
  Tipo: chore
  Spec: despliegue/README.md
  Evidencia: D-29 y D-30; despliegue/docker-compose.yml (PostgreSQL 18 + PostgREST + Nginx + backend); database/scripts/instalar_local.sh (34 migraciones en PostgreSQL 18 temporal, segunda corrida sin cambios; service_role lee y registra, anon sin acceso); migración 31 (I-20) con pruebas; Dockerfile standalone probado con node server.js (/api/salud 200, sin token 401); scripts/armar_rama_despliegue.sh; ruta de Archivo Central solo para rol area; npm test 21/21, tsc backend 0, tsc frontend 28 (línea base), vite build limpio.
  Pendiente: probar docker compose en un servidor (Docker estaba apagado); nivel_formacion sin RLS (migración 27); prueba desactualizada de historias (D-27); exportar la registrar_transferencia original; revisión humana

- [ ] SGD-095: [BUG] Rutas de transferencias sin autenticación: GET/POST /api/transferencias y GET /api/transferencias/{id}
  Tipo: bug
  Prioridad: alta (bloqueaba el despliegue)
  Requisito: RF-AC-009, RF-AC-023, regla 10 (permisos validados en el backend)
  Evidencia: las tres rutas exigen sesión (obtenerUsuarioAutenticado) y el permiso cargas.transferencia con autorizar() (fn_autorizar, migración 32: audita el intento denegado con usuario y acción; sin la migración revisa el permiso sin auditar); Dependencia solo lista y abre las suyas (otra dependencia → 404) y solo registra para la suya (403); registrar_transferencia recibe el usuario que registra (antes null). Pruebas: probar_local.sh 165 OK (2 nuevas de fn_autorizar); en vivo contra el backend de desarrollo: sin token 401 en las tres; con el usuario de desarrollo (con permiso) lista y detalle 200, POST vacío 400 de validación; tsc backend 0, lint 0 errores.
  Pendiente: aplicar la migración 32 en Supabase; revisión humana. Código de dybala1812, corregido a pedido del usuario.
