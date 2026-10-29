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
