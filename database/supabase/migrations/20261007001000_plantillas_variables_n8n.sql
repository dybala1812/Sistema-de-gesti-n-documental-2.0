-- =============================================================================
--  10 Plantillas de correo alineadas con las variables que envían los flujos n8n
--  (F2 remisión/devolución, F4 recordatorio → F5 envío).
--
--  Problema: remision y devolucion no mostraban {mensaje} (lo que escribe Archivo
--  Central / lo que falta en la respuesta) y devolucion usaba {plazo}, que F2 envía
--  vacío; recordatorio usaba {respuesta} pero F4 envía la lista en {pendientes}.
--  Solo se actualizan las plantillas que siguen con el texto original (no se pisan
--  las personalizadas desde la pantalla de Plantillas).
-- =============================================================================

with nuevas(codigo, asunto, cuerpo) as (
  values
  ('remision',
   '[SGD {consecutivo}] {asunto}',
   E'Señores {dependencia}:\n\nRemitimos la comunicación {consecutivo} sobre "{asunto}" para su atención. Plazo de respuesta: {plazo}.\n\n{mensaje}\n\nResponda este correo sin modificar el asunto.\n\nArchivo Central'),
  ('devolucion',
   '[SGD {consecutivo}] Respuesta incompleta: {asunto}',
   E'Señores {dependencia}:\n\nLa respuesta a la comunicación {consecutivo} sobre "{asunto}" está incompleta:\n\n{mensaje}\n\nPor favor compleméntela respondiendo este correo sin modificar el asunto.\n\nArchivo Central'),
  ('recordatorio',
   'Comunicaciones pendientes de respuesta',
   E'Señores {dependencia}:\n\nLas siguientes comunicaciones superaron su plazo de respuesta:\n\n{pendientes}\n\nResponda cada una desde su correo original sin modificar el asunto.\n\nArchivo Central')
)
update plantilla_correo p
   set asunto = n.asunto,
       cuerpo = n.cuerpo,
       cuerpo_original = n.cuerpo
  from nuevas n
 where p.codigo = n.codigo
   and p.cuerpo = p.cuerpo_original;   -- no tocar plantillas personalizadas
