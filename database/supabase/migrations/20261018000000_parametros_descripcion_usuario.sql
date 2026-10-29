-- SGD-090: las descripciones de los parámetros se muestran en pantalla (Catálogos › Parámetros).
-- Se reescriben en lenguaje de usuario, sin códigos de requisitos (RF/RN/RNF-AC, P-xx).
-- Solo cambia el texto: los valores configurados no se tocan.
update parametro p
   set descripcion = v.descripcion,
       actualizado_en = now()
  from (values
    ('anios_minimos_transferencia',     'Años que los documentos permanecen en la dependencia antes de poder transferirse al Archivo Central. Se transfiere hasta el año actual menos este número.'),
    ('tamano_maximo_archivo_mb',        'Tamaño máximo de cada archivo que se sube, en megabytes (MB).'),
    ('formatos_permitidos',             'Tipos de archivo que se pueden subir, escritos como extensiones separadas por coma (por ejemplo: pdf, docx, jpg).'),
    ('plazo_respuesta_dias_habiles',    'Días hábiles que tiene una dependencia para responder una comunicación que se le remitió.'),
    ('recordatorio_cada_dias_habiles',  'Días hábiles que deben pasar entre dos recordatorios de la misma comunicación.'),
    ('max_recordatorios_antes_escalar', 'Cantidad de recordatorios sin respuesta después de la cual la comunicación se marca para escalar.'),
    ('umbral_confianza_ia',             'Confianza mínima, de 0 a 1, para que una sugerencia de la inteligencia artificial se muestre como confiable. Por debajo se marca como de baja confianza.'),
    ('ia_habilitada',                   'Activa o desactiva las sugerencias de clasificación hechas con inteligencia artificial. Siempre requieren confirmación de una persona.'),
    ('buzon_archivo_central',           'Correo institucional del que se leen las comunicaciones que llegan al Archivo Central.')
  ) as v(clave, descripcion)
 where p.clave = v.clave
   and p.descripcion is distinct from v.descripcion;
