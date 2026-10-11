-- =============================================================================
--  Datos iniciales obligatorios (configuración). Idempotente.
--  Los valores marcados "tentativo" están por confirmar con el cliente (P-14).
-- =============================================================================

-- ── Parámetros (RF-AC-006) ──────────────────────────────────────────────────
insert into parametro (clave, valor, tipo, descripcion, minimo, maximo) values
  ('anios_minimos_transferencia',     '2',   'entero',  'RN-AC-03: años en archivo de gestión antes de transferir (año actual − N).', 0, 10),
  ('tamano_maximo_archivo_mb',        '50',  'entero',  'RNF-AC-08: tamaño máximo por archivo en MB (tentativo).', 1, 500),
  ('formatos_permitidos',             'pdf,jpg,jpeg,png,xlsx', 'lista', 'RNF-AC-08: extensiones aceptadas.', null, null),
  ('plazo_respuesta_dias_habiles',    '5',   'entero',  'RF-AC-016: plazo por defecto de respuesta de las dependencias (tentativo; el mockup alerta a los 5 días).', 1, 60),
  ('recordatorio_cada_dias_habiles',  '2',   'entero',  'RF-AC-018: no recordar la misma comunicación antes de N días hábiles.', 1, 30),
  ('max_recordatorios_antes_escalar', '3',   'entero',  'RF-AC-018: tras N recordatorios se marca para escalar.', 1, 10),
  ('umbral_confianza_ia',             '0.70','decimal', 'RF-AC-012: por debajo de este valor la sugerencia se muestra como baja confianza (tentativo).', 0, 1),
  ('ia_habilitada',                   'false','booleano','RF-AC-012: activa la sugerencia con IA (P-13).', null, null),
  ('buzon_archivo_central',           'correspondencia@uniautonoma.edu.co', 'texto', 'Buzón institucional que lee n8n (dato del mockup; confirmar).', null, null)
on conflict (clave) do nothing;

-- ── Plantillas de correo (RF-AC-006) ────────────────────────────────────────
insert into plantilla_correo (codigo, nombre, asunto, cuerpo, cuerpo_original) values
  ('acuse_recibo', 'Acuse de recibo',
   '[SGD {consecutivo}] Recibimos su comunicación',
   E'Estimado(a) {nombre}:\n\nLe confirmamos que recibimos su comunicación sobre "{asunto}" el {fecha}. Quedó registrada con el consecutivo {consecutivo}.\n\nPara cualquier consulta, responda este correo sin modificar el asunto.\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca',
   E'Estimado(a) {nombre}:\n\nLe confirmamos que recibimos su comunicación sobre "{asunto}" el {fecha}. Quedó registrada con el consecutivo {consecutivo}.\n\nPara cualquier consulta, responda este correo sin modificar el asunto.\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca'),
  ('remision', 'Remisión a dependencia',
   '[SGD {consecutivo}] {asunto}',
   E'Señores {dependencia}:\n\nRemitimos la comunicación {consecutivo} sobre "{asunto}" para su atención. Plazo de respuesta: {plazo}.\n\n{mensaje}\n\nResponda este correo sin modificar el asunto.\n\nArchivo Central',
   E'Señores {dependencia}:\n\nRemitimos la comunicación {consecutivo} sobre "{asunto}" para su atención. Plazo de respuesta: {plazo}.\n\n{mensaje}\n\nResponda este correo sin modificar el asunto.\n\nArchivo Central'),
  ('devolucion', 'Devolución a dependencia',
   '[SGD {consecutivo}] Respuesta incompleta: {asunto}',
   E'Señores {dependencia}:\n\nLa respuesta a la comunicación {consecutivo} sobre "{asunto}" está incompleta:\n\n{mensaje}\n\nPor favor compleméntela respondiendo este correo sin modificar el asunto.\n\nArchivo Central',
   E'Señores {dependencia}:\n\nLa respuesta a la comunicación {consecutivo} sobre "{asunto}" está incompleta:\n\n{mensaje}\n\nPor favor compleméntela respondiendo este correo sin modificar el asunto.\n\nArchivo Central'),
  ('respuesta', 'Respuesta al remitente',
   '[SGD {consecutivo}] Respuesta a su comunicación',
   E'Estimado(a) {nombre}:\n\nEn atención a su comunicación {consecutivo} sobre "{asunto}", le informamos:\n\n{respuesta}\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca',
   E'Estimado(a) {nombre}:\n\nEn atención a su comunicación {consecutivo} sobre "{asunto}", le informamos:\n\n{respuesta}\n\nCordialmente,\nArchivo Central\nUniversidad Autónoma del Cauca'),
  ('recordatorio', 'Recordatorio a dependencia',
   'Comunicaciones pendientes de respuesta',
   E'Señores {dependencia}:\n\nLas siguientes comunicaciones superaron su plazo de respuesta:\n\n{pendientes}\n\nResponda cada una desde su correo original sin modificar el asunto.\n\nArchivo Central',
   E'Señores {dependencia}:\n\nLas siguientes comunicaciones superaron su plazo de respuesta:\n\n{pendientes}\n\nResponda cada una desde su correo original sin modificar el asunto.\n\nArchivo Central'),
  ('resumen', 'Resumen diario para Archivo Central',
   'Resumen diario de comunicaciones — {fecha}',
   E'Resumen del {fecha}:\n\n{respuesta}',
   E'Resumen del {fecha}:\n\n{respuesta}')
on conflict (codigo) do nothing;

-- ── Matriz de permisos por perfil (F-02 §2.3) ───────────────────────────────
insert into permiso_perfil (perfil, funcion) values
  -- Archivo Central: todo el módulo salvo usuarios y parámetros sensibles.
  ('archivo_central', 'catalogos.gestionar'),
  ('archivo_central', 'plantillas.gestionar'),
  ('archivo_central', 'cargas.documento'),
  ('archivo_central', 'cargas.transferencia'),
  ('archivo_central', 'cargas.historias'),
  ('archivo_central', 'cargas.historico'),
  ('archivo_central', 'transferencias.recibir'),
  ('archivo_central', 'documentos.clasificar'),
  ('archivo_central', 'documentos.consultar'),
  ('archivo_central', 'documentos.descargar'),
  ('archivo_central', 'ia.sugerir'),
  ('archivo_central', 'comunicaciones.gestionar'),
  ('archivo_central', 'comunicaciones.consultar'),
  ('archivo_central', 'historias.consultar'),
  ('archivo_central', 'historias.gestionar'),
  ('archivo_central', 'registros.anular'),
  -- Dependencia: transferir y consultar lo suyo (el filtro por dependencia lo hace fn_puede_ver_dependencia).
  ('dependencia', 'cargas.transferencia'),
  ('dependencia', 'documentos.consultar'),
  ('dependencia', 'comunicaciones.consultar'),
  -- Registro Académico: historias activas (el filtro por estado lo hace fn_puede_ver_historia).
  ('registro_academico', 'cargas.historias'),
  ('registro_academico', 'historias.consultar'),
  ('registro_academico', 'historias.gestionar'),
  -- Secretaría General: consulta.
  ('secretaria_general', 'documentos.consultar'),
  ('secretaria_general', 'comunicaciones.consultar'),
  ('secretaria_general', 'historias.consultar'),
  -- Administrador: catálogos, usuarios, parámetros y auditoría.
  ('administrador', 'catalogos.gestionar'),
  ('administrador', 'plantillas.gestionar'),
  ('administrador', 'usuarios.gestionar'),
  ('administrador', 'parametros.gestionar'),
  ('administrador', 'auditoria.consultar')
on conflict do nothing;
-- P-09 pendiente: qué perfiles pueden descargar. Por ahora solo Archivo Central.

-- ── Tipos documentales base (RF-AC-004) ─────────────────────────────────────
insert into tipo_documental (nombre)
select n from unnest(array['Acta','Memorando','Circular','Resolución','Comprobante de egreso',
                           'Convenio','Contrato','Informe','Oficio','Certificado','Factura']) n
where not exists (select 1 from tipo_documental t where lower(t.nombre) = lower(n));
