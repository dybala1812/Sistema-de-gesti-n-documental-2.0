-- =============================================================================
--  Pruebas de reglas de negocio de la base de datos (SGD · Archivo Central)
--  Requiere: migraciones + seed.sql + seed_demo.sql.
--  Ejecutar:  psql -v ON_ERROR_STOP=1 -f tests/pruebas_reglas.sql
--  Todo corre en una transacción que se revierte al final (no deja datos).
--  Cada bloque lanza excepción si la regla no se cumple.
-- =============================================================================
\set ON_ERROR_STOP 1
begin;

-- Helper: ejecuta SQL y exige que falle con un mensaje que contenga el patrón.
create function pg_temp.debe_fallar(p_sql text, p_patron text)
returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception 'FALLO: se esperaba error "%" y no ocurrió. SQL: %', p_patron, p_sql;
exception when others then
  if sqlerrm like 'FALLO:%' then raise; end if;
  if position(lower(p_patron) in lower(sqlerrm)) = 0 then
    raise exception 'FALLO: error distinto. Esperado "%", obtenido "%"', p_patron, sqlerrm;
  end if;
end $$;

create function pg_temp.ok(p_cond boolean, p_msg text)
returns void language plpgsql as $$
begin
  if not coalesce(p_cond, false) then raise exception 'FALLO: %', p_msg; end if;
  raise notice 'OK  %', p_msg;
end $$;

create function pg_temp.nuevo_archivo(p_hash text, p_nombre text default 'doc.pdf')
returns uuid language sql as $$
  insert into archivo (ruta_relativa, nombre_original, extension, mime, tamano_bytes, hash_sha256)
  values ('pruebas/' || gen_random_uuid() || '.pdf', p_nombre, 'pdf', 'application/pdf', 1000, p_hash)
  returning id
$$;

-- ── Usuarios desde NOVA (sin login) ─────────────────────────────────────────
do $$
declare u usuario; u2 usuario;
begin
  u := fn_sincronizar_usuario_nova('{
    "id": "11111111-1111-1111-1111-111111111111", "email": "diana.paz@uniautonoma.edu.co",
    "username": "dpaz", "nombre": "Diana", "apellido": "Paz", "tipo_documento": "CC",
    "cedula": "1061000000", "is_staff": false, "activo": true, "roles": ["GESTOR"],
    "dependency": {"id": "22222222-2222-2222-2222-222222222222", "name": "Secretaría General", "code": "110", "email": "x@y.co"}
  }'::jsonb);
  perform pg_temp.ok(u.dependencia_id = (select id from dependencia where codigo = '110'), 'usuario NOVA: dependencia mapeada por código');
  perform pg_temp.ok((select nova_dependency_id from dependencia where codigo = '110') = '22222222-2222-2222-2222-222222222222', 'usuario NOVA: enlace de dependencia guardado');
  perform pg_temp.ok(u.perfil is null and not fn_usuario_puede_ingresar(u.id), 'usuario nuevo sin perfil no puede ingresar');

  update usuario set perfil = 'archivo_central', dependencia_id = (select id from dependencia where codigo = '140') where id = u.id;
  u2 := fn_sincronizar_usuario_nova('{"id": "11111111-1111-1111-1111-111111111111", "email": "diana.paz@uniautonoma.edu.co",
    "nombre": "Diana M.", "apellido": "Paz", "dependency": "22222222-2222-2222-2222-222222222222"}'::jsonb);
  perform pg_temp.ok(u2.id = u.id and u2.nombre = 'Diana M.', 'resincronizar actualiza datos sin duplicar');
  perform pg_temp.ok(u2.dependencia_id = (select id from dependencia where codigo = '140'), 'resincronizar no pisa la dependencia asignada por ADM');
  perform pg_temp.ok(fn_usuario_puede_ingresar(u.id), 'usuario con perfil activo puede ingresar');

  update usuario set estado = 'inactivo' where id = u.id;
  perform pg_temp.ok(not fn_usuario_puede_ingresar(u.id), 'RF-AC-005: usuario inactivo no puede ingresar');
  update usuario set estado = 'activo' where id = u.id;

  perform pg_temp.debe_fallar($q$ select fn_sincronizar_usuario_nova('{"email":"a@b.co"}') $q$, 'Perfil de NOVA inválido');
  perform pg_temp.debe_fallar($q$ update usuario set perfil = 'dependencia', dependencia_id = null where nova_user_id = '11111111-1111-1111-1111-111111111111' $q$, 'usuario_dependencia_requiere_dep');
end $$;

select set_config('app.usuario_id', (select id::text from usuario where nova_user_id = '11111111-1111-1111-1111-111111111111'), true);

-- ── Catálogos ────────────────────────────────────────────────────────────────
do $$
begin
  perform pg_temp.debe_fallar($q$ insert into dependencia (codigo, nombre, correo_oficial) values ('999','X','RECTORIA@uniautonoma.edu.co') $q$, 'dependencia_correo_unico');
  perform pg_temp.debe_fallar($q$ insert into dependencia (codigo, nombre, correo_oficial) values ('100','X','nuevo@uniautonoma.edu.co') $q$, 'dependencia_codigo_key');
  -- RF-AC-003: mismo asunto en otra dependencia es válido; en la misma, no.
  insert into asunto (dependencia_id, nombre, trd_id) select d.id, 'Resoluciones', t.id from dependencia d, trd t where d.codigo = '120' and t.codigo = '120.03';
  perform pg_temp.ok(true, 'RF-AC-003: mismo asunto en otra dependencia permitido');
  perform pg_temp.debe_fallar($q$ insert into asunto (dependencia_id, nombre, trd_id) select d.id, 'RESOLUCIONES', t.id from dependencia d, trd t where d.codigo = '120' and t.codigo = '120.03' $q$, 'asunto_nombre_por_dependencia');
  -- RN-AC-12: sin borrado.
  perform pg_temp.debe_fallar($q$ delete from dependencia where codigo = '180' $q$, 'RN-AC-12');
  perform pg_temp.debe_fallar($q$ delete from tipo_documental $q$, 'RN-AC-12');
  perform pg_temp.debe_fallar($q$ update parametro set valor = '99' where clave = 'anios_minimos_transferencia' $q$, 'parametro_rango');
  perform pg_temp.debe_fallar($q$ update parametro set valor = 'abc' where clave = 'tamano_maximo_archivo_mb' $q$, 'parametro_rango');
end $$;

-- ── Documentos: estado, duplicados y anulación ──────────────────────────────
do $$
declare
  v_dep bigint := (select id from dependencia where codigo = '110');
  v_asunto bigint := (select id from asunto where dependencia_id = (select id from dependencia where codigo = '110') and nombre = 'Actas');
  v_hash text := repeat('a', 64);
  v_doc bigint;
begin
  insert into documento (archivo_id, dependencia_id, anio, origen)
  values (pg_temp.nuevo_archivo(v_hash), v_dep, 2024, 'documento_individual') returning id into v_doc;
  perform pg_temp.ok((select estado from documento where id = v_doc) = 'por_clasificar', 'RF-AC-008: sin datos queda por clasificar');
  perform pg_temp.ok((select hash_sha256 from documento where id = v_doc) = v_hash, 'hash copiado desde archivo');

  update documento set asunto_id = v_asunto, fecha_documento = '2024-05-02' where id = v_doc;
  perform pg_temp.ok((select estado from documento where id = v_doc) = 'clasificado', 'RF-AC-011: con asunto y fecha pasa a clasificado');
  perform pg_temp.ok((select clasificado_por from documento where id = v_doc) is not null, 'registra quién clasificó');

  -- RN-AC-11: mismo hash en el mismo expediente = duplicado.
  perform pg_temp.debe_fallar(format($q$ insert into documento (archivo_id, dependencia_id, anio, asunto_id, fecha_documento, origen) values (pg_temp.nuevo_archivo(%L), %s, 2024, %s, '2024-01-01', 'documento_individual') $q$, v_hash, v_dep, v_asunto), 'documento_sin_duplicados');
  -- Mismo hash en otro año (otro expediente) sí se permite.
  insert into documento (archivo_id, dependencia_id, anio, asunto_id, fecha_documento, origen)
  values (pg_temp.nuevo_archivo(v_hash), v_dep, 2023, v_asunto, '2023-01-01', 'documento_individual');
  perform pg_temp.ok(true, 'RN-AC-11: mismo hash en otro expediente permitido');

  -- RN-AC-02: el asunto debe ser de la misma dependencia.
  perform pg_temp.debe_fallar(format($q$ insert into documento (archivo_id, dependencia_id, anio, asunto_id, origen) values (pg_temp.nuevo_archivo(%L), (select id from dependencia where codigo='100'), 2024, %s, 'documento_individual') $q$, repeat('b',64), v_asunto), 'RN-AC-02');

  -- RF-AC-024: anular exige motivo, conserva el registro y libera el hash.
  perform pg_temp.debe_fallar(format('update documento set estado = %L where id = %s', 'anulado', v_doc), 'documento_anulacion_con_motivo');
  update documento set estado = 'anulado', anulado_motivo = 'Cargado por error' where id = v_doc;
  perform pg_temp.ok((select estado from documento where id = v_doc) = 'anulado', 'RF-AC-024: anulado y sigue en la base');
  insert into documento (archivo_id, dependencia_id, anio, asunto_id, fecha_documento, origen)
  values (pg_temp.nuevo_archivo(v_hash), v_dep, 2024, v_asunto, '2024-05-02', 'documento_individual');
  perform pg_temp.ok(true, 'tras anular se puede volver a cargar el archivo');
  perform pg_temp.debe_fallar(format('delete from documento where id = %s', v_doc), 'RN-AC-12');
  perform pg_temp.ok((select count(*) from v_arbol_archivo where codigo_dependencia = '110' and asunto = 'Actas') >= 1, 'v_arbol_archivo cuenta clasificados');
end $$;

-- ── Lotes ────────────────────────────────────────────────────────────────────
do $$
declare v_lote bigint;
begin
  insert into lote_carga (codigo, tipo) values ('L-TEST-001', 'documento_individual') returning id into v_lote;
  insert into lote_item (lote_id, nombre_origen, resultado) values (v_lote, 'a.pdf', 'aceptado');
  insert into lote_item (lote_id, nombre_origen, resultado, motivo) values (v_lote, 'b.pdf', 'duplicado', 'Mismo hash que documento 1');
  insert into lote_item (lote_id, nombre_origen, resultado, motivo) values (v_lote, 'c.exe', 'error', 'Formato no permitido');
  perform pg_temp.ok((select (aceptados, duplicados, errores, total_items) = (1, 1, 1, 3) from lote_carga where id = v_lote), 'RF-AC-007: contadores del lote 1/1/1');
  perform pg_temp.debe_fallar(format($q$ insert into lote_item (lote_id, nombre_origen, resultado) values (%s, 'd.pdf', 'error') $q$, v_lote), 'lote_item_error_con_motivo');
end $$;

-- ── Transferencias: regla de los dos años ───────────────────────────────────
do $$
declare
  v_anio_actual int := extract(year from current_date);
  v_tr bigint;
begin
  insert into transferencia (codigo, dependencia_id, anio, tipo, funcionario_entrega)
  values ('TR-TEST-1', (select id from dependencia where codigo = '110'), v_anio_actual - 1, 'fisica', 'Carolina Muñoz') returning id into v_tr;
  perform pg_temp.debe_fallar(format($q$ update transferencia set estado = 'recibida' where id = %s $q$, v_tr), 'RN-AC-03');

  insert into transferencia (codigo, dependencia_id, anio, tipo, funcionario_entrega)
  values ('TR-TEST-2', (select id from dependencia where codigo = '110'), v_anio_actual - 2, 'digital', 'Carolina Muñoz') returning id into v_tr;
  update transferencia set estado = 'recibida' where id = v_tr;
  perform pg_temp.ok((select recibido_en is not null from transferencia where id = v_tr), 'RN-AC-03: año actual − 2 se puede recibir');
  perform pg_temp.ok(not exists (select 1 from v_dependencias_pendientes_transferir where codigo = '110'), 'dependencia que transfirió sale de pendientes');
  perform pg_temp.ok(exists (select 1 from v_dependencias_pendientes_transferir where codigo = '100'), 'dependencia sin transferir aparece en pendientes');
end $$;

-- ── Consecutivos ─────────────────────────────────────────────────────────────
do $$
declare a text; b text; c text;
begin
  select consecutivo into a from fn_siguiente_consecutivo('INT', 2090);
  select consecutivo into b from fn_siguiente_consecutivo('INT', 2090);
  select consecutivo into c from fn_siguiente_consecutivo('INT', 2091);
  perform pg_temp.ok(a = 'INT-2090-000001' and b = 'INT-2090-000002', 'RN-AC-08: consecutivos secuenciales por tipo y año');
  perform pg_temp.ok(c = 'INT-2091-000001', 'RN-AC-08: el consecutivo reinicia cada año');

  -- RN-AC-15 / SGD-089: un registro que falla la validación no consume consecutivo
  -- (el contador se incrementa en la misma transacción y se revierte con el error).
  perform pg_temp.debe_fallar($q$ insert into comunicacion (tipo, origen, anio, asunto) values ('INT', 'manual', 2093, null) $q$, 'asunto');
  perform pg_temp.debe_fallar($q$ insert into comunicacion (tipo, origen, anio, asunto) values ('SAL', 'manual', 2093, 'Salida sin entrada') $q$, 'comunicacion_salida_enlazada');
  select consecutivo into a from fn_siguiente_consecutivo('INT', 2093);
  select consecutivo into b from fn_siguiente_consecutivo('SAL', 2093);
  perform pg_temp.ok(a = 'INT-2093-000001' and b = 'SAL-2093-000001', 'RN-AC-15: la validación fallida no consume consecutivo');
end $$;

-- ── Circuito de comunicaciones ──────────────────────────────────────────────
do $$
declare
  e comunicacion; e2 comunicacion; s comunicacion;
  v_dep bigint := (select id from dependencia where codigo = '150');
begin
  e := fn_registrar_correo_entrante('<msg-1@mail>', 'Luisa Ante', 'luisa@estudiantes.uniautonoma.edu.co',
                                    'Solicitud de certificado de notas', 'Buenos días...', now());
  perform pg_temp.ok(e.consecutivo like 'ENT-' || extract(year from now()) || '-%' and e.estado = 'nueva', 'RF-AC-015: correo registrado como ENT en estado nueva');
  e2 := fn_registrar_correo_entrante('<msg-1@mail>', 'Luisa Ante', 'luisa@estudiantes.uniautonoma.edu.co', 'otro', null, now());
  perform pg_temp.ok(e2.id = e.id and (select count(*) from comunicacion where message_id = '<msg-1@mail>') = 1, 'RNF-AC-04: mismo Message-ID no duplica');
  perform pg_temp.ok(exists (select 1 from comunicacion_evento where comunicacion_id = e.id and tipo = 'recepcion'), 'evento de recepción registrado');

  -- RN-AC-09: transiciones inválidas.
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'cerrada' where id = %s $q$, e.id), 'RN-AC-09');
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'respondida_dependencia' where id = %s $q$, e.id), 'RN-AC-09');
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'remitida' where id = %s $q$, e.id), 'RF-AC-016');

  -- RF-AC-016: remitir y recibir respuesta.
  perform fn_remitir_comunicacion(e.id, v_dep, 5, '<remision-1@sgd>');
  perform pg_temp.ok((select estado = 'remitida' and fecha_limite > current_date from comunicacion where id = e.id), 'RF-AC-016: remitida con fecha límite en días hábiles');
  perform pg_temp.ok(fn_buscar_comunicacion_respondida('RE: [SGD ' || e.consecutivo || '] Solicitud', null) = e.id, 'RF-AC-016: respuesta asociada por etiqueta');
  perform pg_temp.ok(fn_buscar_comunicacion_respondida('RE: Solicitud', '<remision-1@sgd>') = e.id, 'RF-AC-016: respuesta asociada por In-Reply-To');
  perform pg_temp.ok(fn_buscar_comunicacion_respondida('Hola', '<otro@x>') is null, 'correo sin etiqueta ni In-Reply-To no se asocia');

  update comunicacion set estado = 'respondida_dependencia' where id = e.id;
  update comunicacion set estado = 'devuelta' where id = e.id;
  update comunicacion set estado = 'respondida_dependencia' where id = e.id;
  perform pg_temp.ok(true, 'RN-AC-09: ciclo remitida → respondida → devuelta → respondida válido');

  -- RN-AC-09: solo se cierra al responder al remitente.
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'cerrada' where id = %s $q$, e.id), 'falta la comunicación de salida');
  s := fn_responder_remitente(e.id, '[SGD ' || e.consecutivo || '] Respuesta', 'Adjuntamos su certificado', '<resp-1@sgd>');
  perform pg_temp.ok(s.tipo = 'SAL' and s.consecutivo like 'SAL-%' and s.comunicacion_entrada_id = e.id, 'RF-AC-017: salida SAL enlazada a la entrada');
  perform pg_temp.ok((select estado from comunicacion where id = e.id) = 'cerrada', 'RF-AC-017: la entrada queda cerrada');
  perform pg_temp.debe_fallar(format($q$ select fn_responder_remitente(%s, 'x', 'y') $q$, e.id), 'RF-AC-017');
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'anulada', anulado_motivo = 'x' where id = %s $q$, e.id), 'RN-AC-09');

  -- Anulación con motivo.
  e2 := fn_registrar_correo_entrante('<msg-2@mail>', 'Spam', 'spam@x.co', 'Promo', null, now());
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'anulada' where id = %s $q$, e2.id), 'comunicacion_anulacion_con_motivo');
  update comunicacion set estado = 'anulada', anulado_motivo = 'Correo no institucional' where id = e2.id;
  perform pg_temp.ok((select estado from comunicacion where id = e2.id) = 'anulada', 'RF-AC-024: comunicación anulada');
end $$;

-- ── Recordatorios ────────────────────────────────────────────────────────────
do $$
declare e comunicacion; i int;
begin
  e := fn_registrar_correo_entrante('<msg-3@mail>', 'Juan', 'juan@x.co', 'Homologación', null, now());
  perform fn_remitir_comunicacion(e.id, (select id from dependencia where codigo = '170'), 1);
  update comunicacion set fecha_limite = current_date - 10 where id = e.id;
  perform pg_temp.ok(not fn_es_dia_habil(current_date)
                     or exists (select 1 from fn_comunicaciones_a_recordar(current_date) where comunicacion_id = e.id),
                     'RF-AC-018: comunicación vencida aparece para recordar (en día hábil)');
  for i in 1..3 loop perform fn_registrar_recordatorio(e.id); end loop;
  perform pg_temp.ok((select por_escalar and n_recordatorios = 3 from comunicacion where id = e.id), 'RF-AC-018: tras 3 recordatorios se marca para escalar');
  perform pg_temp.ok(not exists (select 1 from fn_comunicaciones_a_recordar(current_date) where comunicacion_id = e.id), 'no se recuerda dos veces el mismo día');
  perform pg_temp.ok(fn_dias_habiles_entre('2026-10-09', '2026-10-12') = 1, 'días hábiles: viernes → lunes = 1');
end $$;

-- ── Registro histórico ──────────────────────────────────────────────────────
do $$
begin
  insert into comunicacion (tipo, origen, anio, numero, consecutivo_original, asunto, remitente_nombre, fecha_recepcion)
  values ('ENT', 'historico', 2024, 900001, '385', 'Invitación a mesa departamental', 'Gobernación', '2024-02-29');
  perform pg_temp.ok((select estado = 'cerrada' and consecutivo = 'ENT-2024-900001' from comunicacion where consecutivo_original = '385' and anio = 2024), 'RF-AC-019: histórico entra cerrado conservando el número original');
  perform pg_temp.debe_fallar($q$ insert into comunicacion (tipo, origen, anio, numero, consecutivo_original, asunto, fecha_recepcion) values ('ENT', 'historico', 2024, 900002, '385', 'dup', '2024-02-29') $q$, 'comunicacion_historico_unico');
end $$;

-- ── Historias académicas ────────────────────────────────────────────────────
do $$
declare
  v_est bigint; v_h_activa bigint; v_h_grad bigint;
  v_ra bigint; v_ac bigint := fn_usuario_actual();
  v_hash text := repeat('c', 64);
begin
  insert into estudiante (numero_documento, codigo, apellidos, nombres) values ('1063600825', 'UAC-2015-1504', 'Astudillo Guzmán', 'Daniela') returning id into v_est;
  insert into historia_academica (estudiante_id, programa_id) values (v_est, (select id from programa_academico where codigo = 'DER')) returning id into v_h_activa;
  insert into historia_academica (estudiante_id, programa_id, estado, anio) values (v_est, (select id from programa_academico where codigo = 'EGP'), 'graduado', 2019) returning id into v_h_grad;
  perform pg_temp.ok((select custodia from historia_academica where id = v_h_grad) = 'archivo_central', 'RN-AC-06: graduado queda en custodia de Archivo Central');
  perform pg_temp.debe_fallar(format($q$ update historia_academica set estado = 'retirado' where id = %s $q$, v_h_activa), 'historia_anio_si_inactiva');

  insert into historia_documento (historia_id, archivo_id) values (v_h_grad, pg_temp.nuevo_archivo(v_hash));
  perform pg_temp.debe_fallar(format($q$ insert into historia_documento (historia_id, archivo_id) values (%s, pg_temp.nuevo_archivo(%L)) $q$, v_h_grad, v_hash), 'historia_documento_sin_duplicados');

  -- Permisos: RA solo historias activas; AC todas.
  v_ra := (fn_sincronizar_usuario_nova('{"id":"33333333-3333-3333-3333-333333333333","email":"ra@uniautonoma.edu.co","nombre":"Jorge","apellido":"Imbachí"}'::jsonb)).id;
  update usuario set perfil = 'registro_academico' where id = v_ra;
  perform pg_temp.ok(fn_puede_ver_historia(v_ra, v_h_activa) and not fn_puede_ver_historia(v_ra, v_h_grad), 'RF-AC-020: Registro Académico no ve historias de graduados/retirados');
  perform pg_temp.ok(fn_puede_ver_historia(v_ac, v_h_grad), 'Archivo Central ve todas las historias');
end $$;

-- ── Permisos por dependencia ─────────────────────────────────────────────────
do $$
declare v_dep_user bigint;
begin
  v_dep_user := (fn_sincronizar_usuario_nova('{"id":"44444444-4444-4444-4444-444444444444","email":"mercadeo@uniautonoma.edu.co","nombre":"Juliana","apellido":"Rengifo","dependency":{"id":"55555555-5555-5555-5555-555555555555","code":"120","name":"Mercadeo"}}'::jsonb)).id;
  update usuario set perfil = 'dependencia' where id = v_dep_user;
  perform pg_temp.ok(fn_puede_ver_dependencia(v_dep_user, (select id from dependencia where codigo = '120')), 'Dependencia ve sus carpetas');
  perform pg_temp.ok(not fn_puede_ver_dependencia(v_dep_user, (select id from dependencia where codigo = '100')), 'RF-AC-013: Dependencia no ve carpetas de otra');
  perform pg_temp.ok(fn_tiene_permiso(v_dep_user, 'cargas.transferencia') and not fn_tiene_permiso(v_dep_user, 'documentos.clasificar'), 'matriz de permisos por perfil');
  perform pg_temp.ok(not fn_tiene_permiso(fn_usuario_actual(), 'usuarios.gestionar'), 'Archivo Central no gestiona usuarios');
end $$;

-- ── Registro desde n8n (fn_registrar_comunicacion_n8n) ──────────────────────
do $$
declare
  r1 record; r2 record;
  a1 uuid := pg_temp.nuevo_archivo(repeat('d', 64), 'Solicitud.pdf');
  a2 uuid := pg_temp.nuevo_archivo(repeat('e', 64), 'Soporte.pdf');
begin
  select * into r1 from fn_registrar_comunicacion_n8n('<n8n-1@mail>', 'Ana Ruiz', 'ana@estudiantes.uniautonoma.edu.co',
    'Certificado de estudios', 'Buenos días', now(), null, array[a1]);
  perform pg_temp.ok(r1.creada and r1.estado = 'nueva' and r1.consecutivo like 'ENT-%' and r1.adjuntos = 1,
    'n8n: crea comunicación nueva con consecutivo y adjunto');

  -- Reintento con un adjunto más: no duplica la comunicación, agrega el faltante.
  select * into r2 from fn_registrar_comunicacion_n8n('<n8n-1@mail>', 'Ana Ruiz', 'ana@estudiantes.uniautonoma.edu.co',
    'Certificado de estudios', 'Buenos días', now(), null, array[a1, a2]);
  perform pg_temp.ok(not r2.creada and r2.comunicacion_id = r1.comunicacion_id and r2.adjuntos = 2,
    'n8n: reintento idempotente (misma comunicación, sin duplicar adjuntos)');
  perform pg_temp.ok((select count(*) from comunicacion where message_id = '<n8n-1@mail>') = 1, 'n8n: una sola comunicación por Message-ID');

  perform pg_temp.debe_fallar($q$ select * from fn_registrar_comunicacion_n8n('<n8n-2@mail>', 'X', 'x@x.co', 'A', null, now(), null, array['00000000-0000-0000-0000-000000000001'::uuid]) $q$, 'Adjuntos inexistentes');
  perform pg_temp.ok(not exists (select 1 from comunicacion where message_id = '<n8n-2@mail>'), 'n8n: si un adjunto no existe no se crea nada');
  perform pg_temp.debe_fallar($q$ select * from fn_registrar_comunicacion_n8n('  ', 'X', 'x@x.co', 'A', null, now()) $q$, 'message_id es obligatorio');
end $$;

-- ── Funciones de los flujos n8n (migración 09) ──────────────────────────────
do $$
declare
  ec record; nuevo record; resp record; j jsonb; r record;
  a1 uuid := pg_temp.nuevo_archivo(repeat('f', 64), 'Solicitud.pdf');
  a2 uuid := pg_temp.nuevo_archivo(repeat('0', 64), 'Respuesta.pdf');
  v_dep bigint := (select id from dependencia where codigo = '150');
  v_user bigint := fn_usuario_actual();
  v_id bigint;
begin
  -- F1: correo nuevo
  select * into ec from n8n_estado_correo('<f1-1@mail>', 'Certificado', null, 'pedro@estudiantes.uniautonoma.edu.co');
  perform pg_temp.ok(not ec.ya_procesado and ec.comunicacion_id is null and ec.dependencia_id is null and not ec.es_propio, 'n8n_estado_correo: correo nuevo de un externo');
  select * into nuevo from n8n_registrar_correo_nuevo('<f1-1@mail>', 'Pedro', 'pedro@estudiantes.uniautonoma.edu.co', 'Certificado', 'Hola', now(), null, array[a1], '[{"nombre":"video.mp4","motivo":"413"}]');
  v_id := nuevo.id;
  perform pg_temp.ok(nuevo.consecutivo like 'ENT-%', 'n8n_registrar_correo_nuevo: crea con consecutivo');
  perform n8n_registrar_correo_nuevo('<f1-1@mail>', 'Pedro', 'pedro@estudiantes.uniautonoma.edu.co', 'Certificado', 'Hola', now(), null, array[a1], '[{"nombre":"video.mp4"}]');
  perform pg_temp.ok((select count(*) from comunicacion_evento where comunicacion_id = v_id and tipo = 'nota') = 1, 'n8n_registrar_correo_nuevo: reintento no duplica la nota de adjuntos omitidos');
  select * into ec from n8n_estado_correo('<f1-1@mail>', 'Certificado', null, 'pedro@x.co');
  perform pg_temp.ok(ec.ya_procesado, 'n8n_estado_correo: detecta correo ya procesado');
  select * into ec from n8n_estado_correo('<x@mail>', 'x', null, 'CORRESPONDENCIA@uniautonoma.edu.co');
  perform pg_temp.ok(ec.es_propio, 'n8n_estado_correo: reconoce el buzón propio');
  perform pg_temp.ok((select id from n8n_registrar_error_acuse(v_id, 'SMTP 550')) is not null, 'n8n_registrar_error_acuse');
  perform pg_temp.ok((select count(*) from n8n_guardar_sugerencia(v_id, null)) = 0 and (select count(*) from n8n_guardar_sugerencia(v_id, '{"dependencia":"150"}')) = 1, 'n8n_guardar_sugerencia: nada si detalle es null');

  -- F2: leer y remitir
  j := n8n_leer_remision(v_id, v_dep);
  perform pg_temp.ok(j->>'estado' = 'nueva' and (j->>'dep_id')::bigint = v_dep and j->>'dep_estado' = 'activo' and jsonb_array_length(j->'adjuntos') = 1 and (j->>'plazo_defecto')::int = 5, 'n8n_leer_remision: datos y adjuntos');
  perform pg_temp.ok(n8n_leer_remision(999999, null) = '{"id": null}'::jsonb, 'n8n_leer_remision: {"id": null} si no existe');
  j := n8n_remitir(v_user, v_id, v_dep, 3, '<rem-f2@sgd>', 'Favor responder');
  perform pg_temp.ok(j->>'estado' = 'remitida' and j->>'fecha_limite' is not null, 'n8n_remitir: remitida con fecha límite');

  -- F1: respuesta de la dependencia (por In-Reply-To)
  select * into ec from n8n_estado_correo('<resp-1@mail>', 'RE: Certificado', '<rem-f2@sgd>', 'registro.academico@uniautonoma.edu.co');
  perform pg_temp.ok(ec.comunicacion_id = v_id and ec.dependencia_id = v_dep, 'n8n_estado_correo: asocia la respuesta y reconoce la dependencia');
  select * into resp from n8n_registrar_respuesta_dependencia(v_id, 'registro.academico@uniautonoma.edu.co', 'RE: Certificado', 'Adjunto', '<resp-1@mail>', now()::text, array[a2], '[]');
  perform pg_temp.ok(resp.estado = 'respondida_dependencia', 'n8n_registrar_respuesta_dependencia: cambia de estado');
  select * into ec from n8n_estado_correo('<resp-1@mail>', 'RE: Certificado', '<rem-f2@sgd>', 'registro.academico@uniautonoma.edu.co');
  perform pg_temp.ok(ec.ya_procesado, 'n8n_estado_correo: la respuesta reprocesada se marca ya procesada');

  -- F2: devolver y nueva respuesta
  j := n8n_devolver(v_user, v_id, '<dev-f2@sgd>', v_dep, 'Falta firma');
  perform pg_temp.ok(j->>'estado' = 'devuelta' and (j->>'fecha_limite')::date > current_date, 'n8n_devolver: devuelta con nuevo plazo');
  perform pg_temp.debe_fallar(format($q$ select n8n_devolver(%s, %s, null, (select id from dependencia where codigo='100'), 'x') $q$, v_user, v_id), 'no está remitida a la dependencia');
  perform n8n_registrar_respuesta_dependencia(v_id, 'registro.academico@uniautonoma.edu.co', 'RE: Certificado', 'Ya firmado', '<resp-2@mail>', now()::text, '{}', '[]');

  -- F3: leer entrada y responder
  j := n8n_leer_entrada(v_id);
  perform pg_temp.ok(j->>'estado' = 'respondida_dependencia' and jsonb_array_length(j->'adjuntos') = 2
                     and (select count(*) from jsonb_array_elements(j->'adjuntos') x where (x->>'de_dependencia')::boolean) = 1, 'n8n_leer_entrada: marca los adjuntos de la dependencia');
  perform pg_temp.debe_fallar(format($q$ select n8n_responder(%s, %s, 'RE', 'x', null, array[%L::uuid]) $q$, v_user, v_id, pg_temp.nuevo_archivo(repeat('1',64))), 'no son adjuntos');
  j := n8n_responder(v_user, v_id, 'RE: Certificado', 'Adjuntamos su certificado', '<resp-f3@sgd>', array[a2]);
  perform pg_temp.ok(j->>'consecutivo' like 'SAL-%' and (select estado from comunicacion where id = v_id) = 'cerrada', 'n8n_responder: crea SAL y cierra la entrada');
  perform pg_temp.debe_fallar(format($q$ select * from n8n_registrar_respuesta_dependencia(%s, 'a@b.co', 'x', 'x', '<tarde@mail>', null, '{}', '[]') $q$, v_id), 'RN-AC-09');

  -- Sin asociar, rebote, errores y auditoría
  perform pg_temp.ok((select insertados from n8n_guardar_sin_asociar('<sa-9@mail>', null, 'X', 'x@x.co', 'RE: algo', 'y', now(), 'sin_etiqueta', null, '{}')) = 1
                     and (select insertados from n8n_guardar_sin_asociar('<sa-9@mail>', null, 'X', 'x@x.co', 'RE: algo', 'y', now(), 'sin_etiqueta', null, '{}')) = 0, 'n8n_guardar_sin_asociar: idempotente');
  select * into r from n8n_registrar_rebote(array['<rem-f2@sgd>'], 'mailer-daemon@x.co', 'Undelivered');
  perform pg_temp.ok(r.asociados = 1 and r.auditado, 'n8n_registrar_rebote: asocia el rebote a la comunicación');
  perform pg_temp.ok((n8n_registrar_error_envio(v_user, array[v_id], v_dep, '{"flujo":"F2","error":"x"}')->>'registrados')::int = 1, 'n8n_registrar_error_envio');
  perform pg_temp.ok(n8n_auditar('F3 Responder', '{"error":"x"}')->>'ok' = 'true' and n8n_auditar_error_flujo('F1', '1', 'nodo', 'msg', null), 'n8n_auditar y n8n_auditar_error_flujo');

  -- F4
  perform pg_temp.ok((n8n_es_dia_habil()->>'habil')::boolean = fn_es_dia_habil(current_date), 'n8n_es_dia_habil');
  insert into comunicacion (tipo, origen, asunto, remitente_correo, message_id) values ('ENT', 'correo', 'Vencida F4', 'z@z.co', '<f4@mail>') returning id into v_id;
  perform fn_remitir_comunicacion(v_id, v_dep, 1);
  update comunicacion set fecha_limite = current_date - 3 where id = v_id;
  perform pg_temp.ok(not fn_es_dia_habil(current_date)
                     or exists (select 1 from n8n_recordatorios_pendientes() p, jsonb_array_elements(p.pendientes) x where (x->>'id')::bigint = v_id and p.dependencia_id = v_dep),
                     'n8n_recordatorios_pendientes: agrupa por dependencia');
  j := n8n_registrar_recordatorios(array[v_id], '<rec@sgd>');
  perform pg_temp.ok((j->>'registrados')::int = 1 and (select n_recordatorios from comunicacion where id = v_id) = 1, 'n8n_registrar_recordatorios');
  perform pg_temp.ok(not exists (select 1 from n8n_resumen_dia() where estado in ('cerrada','anulada'))
                     and exists (select 1 from n8n_resumen_dia() where buzon = 'correspondencia@uniautonoma.edu.co' and vencida), 'n8n_resumen_dia: solo activas, con buzón y vencidas');
end $$;

-- ── Plantillas usadas por F5 (migración 10) ─────────────────────────────────
do $$
begin
  perform pg_temp.ok((select cuerpo like '%{mensaje}%' from plantilla_correo where codigo = 'remision'), 'plantilla remision muestra {mensaje}');
  perform pg_temp.ok((select cuerpo like '%{mensaje}%' and cuerpo not like '%{plazo}%' from plantilla_correo where codigo = 'devolucion'), 'plantilla devolucion muestra {mensaje} y no usa {plazo}');
  perform pg_temp.ok((select cuerpo like '%{pendientes}%' from plantilla_correo where codigo = 'recordatorio'), 'plantilla recordatorio muestra {pendientes}');
  perform pg_temp.ok((select bool_and(cuerpo = cuerpo_original) from plantilla_correo), 'plantillas: cuerpo_original actualizado (restablecer funciona)');
end $$;

-- ── Responder directo (migración 12) ────────────────────────────────────────
do $$
declare
  e comunicacion; r comunicacion; s jsonb; j jsonb;
  v_user bigint := fn_usuario_actual();
  n_eventos integer;
begin
  -- 1) Desde "nueva" (el caso que fallaba)
  e := fn_registrar_correo_entrante('<directo-1@mail>', 'Ana Ruiz', 'ana@estudiantes.uniautonoma.edu.co', 'Consulta', 'Hola', now(), null);
  r := fn_responder_directo(v_user, e.id, 'Mensaje de respuesta');
  perform pg_temp.ok(r.estado = 'respondida_dependencia', 'responder directo: nueva → respondida_dependencia');
  perform pg_temp.ok((select count(*) from comunicacion_evento where comunicacion_id = e.id and tipo = 'respuesta_dependencia') = 1,
                     'responder directo: un solo evento de respuesta en el historial');
  perform pg_temp.ok((select (detalle->>'directo')::boolean from comunicacion_evento where comunicacion_id = e.id and tipo = 'respuesta_dependencia') is true,
                     'responder directo: el evento queda marcado como directo');

  -- 2) La bandera no queda activa: otro UPDATE directo sigue bloqueado
  e := fn_registrar_correo_entrante('<directo-2@mail>', 'Luis', 'luis@x.co', 'Otra', 'Hola', now(), null);
  perform pg_temp.debe_fallar(format($q$ update comunicacion set estado = 'respondida_dependencia' where id = %s $q$, e.id), 'RN-AC-09');
  perform pg_temp.ok(coalesce(current_setting('app.responder_directo', true), '') <> 'on', 'la bandera de excepción no queda activa tras responder directo');

  -- 3) Desde "remitida" y "devuelta" también sirve
  e := fn_registrar_correo_entrante('<directo-3@mail>', 'Eva', 'eva@x.co', 'Tercera', 'Hola', now(), null);
  perform fn_remitir_comunicacion(e.id, (select id from dependencia where codigo = '150'), 3);
  r := fn_responder_directo(v_user, e.id, 'x');
  perform pg_temp.ok(r.estado = 'respondida_dependencia', 'responder directo: remitida → respondida_dependencia');

  -- 4) Ya respondida: no cambia de estado y deja constancia
  n_eventos := (select count(*) from comunicacion_evento where comunicacion_id = e.id);
  r := fn_responder_directo(v_user, e.id, 'segunda vez');
  perform pg_temp.ok(r.estado = 'respondida_dependencia' and (select count(*) from comunicacion_evento where comunicacion_id = e.id) = n_eventos + 1,
                     'responder directo: ya respondida deja una nota y no falla');

  -- 5) Cerrada y anulada siguen rechazadas
  perform pg_temp.debe_fallar(format($q$ select fn_responder_directo(%s, %s, 'x') $q$, v_user, (select id from comunicacion where estado = 'cerrada' and tipo = 'ENT' limit 1)), 'cerrada');

  -- 6) Una salida SAL no se puede responder
  perform pg_temp.debe_fallar(format($q$ select fn_responder_directo(%s, %s, 'x') $q$, v_user, (select id from comunicacion where tipo = 'SAL' limit 1)), 'no es una entrada');

  -- 7) El flujo completo: responder directo → n8n_responder cierra y crea la SAL
  e := fn_registrar_correo_entrante('<directo-4@mail>', 'Zoe', 'zoe@x.co', 'Cuarta', 'Hola', now(), null);
  perform fn_responder_directo(v_user, e.id, 'listo');
  j := n8n_leer_entrada(e.id);
  perform pg_temp.ok(j->>'estado' = 'respondida_dependencia', 'F3 puede leer la entrada tras responder directo');
  s := n8n_responder(v_user, e.id, 'RE: Cuarta', 'Su respuesta', '<resp-directa@sgd>', '{}');
  perform pg_temp.ok(s->>'consecutivo' like 'SAL-%' and (select estado from comunicacion where id = e.id) = 'cerrada',
                     'responder directo + F3: crea la SAL y cierra la entrada');
end $$;

-- ── Usuario que actúa (migración 13) ────────────────────────────────────────
do $$
declare e comunicacion; v_actual bigint := fn_usuario_actual();
begin
  perform pg_temp.debe_fallar($q$ select fn_set_usuario_actual(987654) $q$, '[campo:usuario|tipo:existente]');
  perform fn_set_usuario_actual(null);
  perform pg_temp.ok(true, 'fn_set_usuario_actual: acepta null (acción del sistema)');
  perform fn_set_usuario_actual(fn_usuario_actual());
  perform pg_temp.ok(true, 'fn_set_usuario_actual: acepta un usuario existente');
  e := fn_registrar_correo_entrante('<usr-13@mail>', 'Ana', 'ana@x.co', 'Prueba usuario', 'Hola', now(), null);
  perform pg_temp.debe_fallar(format($q$ select n8n_remitir(987654, %s, (select id from dependencia where codigo='150'), 3, '<r@sgd>', 'x') $q$, e.id), 'El usuario 987654 no existe');
  perform pg_temp.ok((select estado from comunicacion where id = e.id) = 'nueva', 'usuario inexistente: la comunicación no cambia de estado');
  perform pg_temp.debe_fallar(format($q$ select n8n_registrar_error_envio(987654, array[%s], null, '{"flujo":"F3"}') $q$, e.id), 'El usuario 987654 no existe');
  perform fn_set_usuario_actual(v_actual);   -- restaura el usuario de la sesión de pruebas
end $$;

-- ── Migración 14: copia de los correos enviados ─────────────────────────────
do $$
declare
  e comunicacion;
  r jsonb;
  r2 jsonb;
begin
  e := fn_registrar_correo_entrante('<copia-14@mail>', 'Ana', 'ana@x.co', 'Prueba copia', 'Hola', now(), null);
  -- Sin comunicacion_id: se resuelve por el consecutivo del asunto.
  r := n8n_registrar_correo_enviado('<env-14@sgd>', 'dep@x.co', format('[SGD %s] Remisión', e.consecutivo), 'Texto de la remisión',
                                    'remision', null, array['ENT-1900-000001', e.consecutivo], '{}', null);
  perform pg_temp.ok((r->>'comunicacion_id')::bigint = e.id, 'correo_enviado: comunicación tomada del consecutivo [SGD]');
  perform pg_temp.ok((r->>'duplicado')::boolean = false, 'correo_enviado: primera copia registrada');
  r2 := n8n_registrar_correo_enviado('<env-14@sgd>', 'dep@x.co', 'otro asunto', 'otro texto', 'remision', null, '{}', '{}', null);
  perform pg_temp.ok((r2->>'duplicado')::boolean and r2->>'id' = r->>'id', 'correo_enviado: idempotente por Message-ID');
  perform pg_temp.ok((select cuerpo from correo_enviado where message_id = '<env-14@sgd>') = 'Texto de la remisión', 'correo_enviado: el reintento no cambia la copia');
  perform pg_temp.debe_fallar($q$ select n8n_registrar_correo_enviado('', 'a@x.co', 'x') $q$, '[campo:message_id|tipo:obligatorio]');
  perform pg_temp.debe_fallar($q$ select n8n_registrar_correo_enviado('<m@x>', '', 'x') $q$, '[campo:para|tipo:obligatorio]');
  perform pg_temp.debe_fallar($q$ select n8n_registrar_correo_enviado('<m@x>', 'a@x.co', 'x', null, null, 987654) $q$, '[campo:comunicacion_id|tipo:existente]');
  perform pg_temp.debe_fallar($q$ update correo_enviado set cuerpo = 'x' $q$, 'inmutable');
  perform pg_temp.debe_fallar($q$ delete from correo_enviado $q$, 'inmutable');
end $$;

-- ── Migración 15: varias respuestas de la dependencia ───────────────────────
do $$
declare
  e comunicacion;
  v_user bigint := fn_usuario_actual();
  v_dep bigint := (select id from dependencia where codigo = '150');
  a1 uuid := pg_temp.nuevo_archivo(repeat('a', 63) || '1', 'respuesta1.pdf');
  a2 uuid := pg_temp.nuevo_archivo(repeat('a', 63) || '2', 'respuesta2.pdf');
  ev1 bigint; ev2 bigint;
begin
  e := fn_registrar_correo_entrante('<varias-15@mail>', 'Ana', 'ana@x.co', 'Varias respuestas', 'Hola', now(), null);
  perform n8n_remitir(v_user, e.id, v_dep, 3, '<rem-15@sgd>', 'Favor responder');
  perform n8n_registrar_respuesta_dependencia(e.id, 'persona1@uniautonoma.edu.co', 'RE: 1', 'Primera respuesta', '<r1-15@mail>', now()::text, array[a1], '[]');
  perform n8n_registrar_respuesta_dependencia(e.id, 'persona2@uniautonoma.edu.co', 'RE: 2', 'Segunda respuesta', '<r2-15@mail>', now()::text, array[a2], '[]');
  select id into ev1 from comunicacion_evento where comunicacion_id = e.id and message_id = '<r1-15@mail>';
  select id into ev2 from comunicacion_evento where comunicacion_id = e.id and message_id = '<r2-15@mail>';
  perform pg_temp.ok((select count(*) from comunicacion_evento where comunicacion_id = e.id and tipo = 'respuesta_dependencia') = 2,
                     'varias respuestas: cada correo es su propio evento');
  perform pg_temp.ok((select detalle->>'cuerpo' from comunicacion_evento where id = ev1) = 'Primera respuesta'
                     and (select detalle->>'cuerpo' from comunicacion_evento where id = ev2) = 'Segunda respuesta',
                     'varias respuestas: no se pierde ni se sobrescribe el texto de ninguna');
  perform pg_temp.ok(exists (select 1 from comunicacion_adjunto where evento_id = ev1 and archivo_id = a1)
                     and exists (select 1 from comunicacion_adjunto where evento_id = ev2 and archivo_id = a2),
                     'varias respuestas: cada adjunto queda con su correo');
  perform pg_temp.ok((select estado from comunicacion where id = e.id) = 'respondida_dependencia', 'varias respuestas: el estado sigue en respondida_dependencia');
  perform n8n_registrar_respuesta_dependencia(e.id, 'persona2@uniautonoma.edu.co', 'RE: 2', 'Segunda respuesta', '<r2-15@mail>', now()::text, array[a2], '[]');
  perform pg_temp.ok((select count(*) from comunicacion_evento where comunicacion_id = e.id and tipo = 'respuesta_dependencia') = 2,
                     'varias respuestas: reintento del mismo correo no duplica');
end $$;

-- ── Migración 16: anular documento desde el backend ─────────────────────────
do $$
declare
  v_user bigint := fn_usuario_actual();
  v_dep bigint := (select id from dependencia where codigo = '150');
  v_doc bigint;
begin
  insert into documento (archivo_id, dependencia_id, anio, origen)
  values (pg_temp.nuevo_archivo(repeat('d', 63) || '6'), v_dep, 2024, 'documento_individual')
  returning id into v_doc;
  perform pg_temp.debe_fallar(format($q$ select fn_anular_documento_usuario(%s, %s, '  ') $q$, v_user, v_doc), '[campo:motivo|tipo:obligatorio]');
  perform pg_temp.debe_fallar(format($q$ select fn_anular_documento_usuario(%s, 987654, 'x') $q$, v_user), '[campo:id|tipo:existente]');
  perform pg_temp.debe_fallar(format($q$ select fn_anular_documento_usuario(987654, %s, 'x') $q$, v_doc), 'El usuario 987654 no existe');
  perform fn_anular_documento_usuario(v_user, v_doc, '  Cargado en la dependencia equivocada ');
  perform pg_temp.ok((select estado = 'anulado' and anulado_motivo = 'Cargado en la dependencia equivocada' and anulado_por = v_user and anulado_en is not null
                        from documento where id = v_doc), 'fn_anular_documento_usuario: anula con motivo, usuario y fecha (sin borrar)');
  perform pg_temp.ok(exists (select 1 from auditoria where recurso_tipo = 'documento' and recurso_id = v_doc::text and accion = 'anular' and usuario_id = v_user),
                     'fn_anular_documento_usuario: la anulación queda auditada con el usuario');
  perform pg_temp.debe_fallar(format($q$ select fn_anular_documento_usuario(%s, %s, 'otra vez') $q$, v_user, v_doc), 'ya está anulado');
  perform fn_set_usuario_actual(v_user);   -- restaura el usuario de la sesión de pruebas
end $$;

-- ── Migración 17: catálogos, parámetros, plantillas y auditoría ─────────────
do $$
declare
  v_ac bigint := fn_usuario_actual();   -- Archivo Central (sesión de pruebas)
  v_adm bigint;
  v_dep bigint;
  r jsonb;
  v_id bigint;
  v_clave text;
begin
  v_adm := (fn_sincronizar_usuario_nova('{"id":"66666666-6666-6666-6666-666666666666","email":"admin.sgd@uniautonoma.edu.co","nombre":"Admin","apellido":"Prueba"}'::jsonb)).id;
  update usuario set perfil = 'administrador' where id = v_adm;
  v_dep := (fn_sincronizar_usuario_nova('{"id":"77777777-7777-7777-7777-777777777777","email":"dep.sgd@uniautonoma.edu.co","nombre":"Dep","apellido":"Prueba"}'::jsonb)).id;
  update usuario set perfil = 'dependencia', dependencia_id = (select id from dependencia where codigo = '150') where id = v_dep;

  -- Crear y editar con el usuario real en la auditoría
  r := fn_catalogo_guardar(v_ac, 'tipo_documental', null, '{"nombre":"Acuerdo de prueba"}');
  v_id := (r->>'id')::bigint;
  perform pg_temp.ok(r->>'nombre' = 'Acuerdo de prueba', 'catálogo: Archivo Central crea un tipo documental');
  perform pg_temp.ok(exists (select 1 from auditoria where recurso_tipo = 'tipo_documental' and recurso_id = v_id::text and accion = 'crear' and usuario_id = v_ac),
                     'catálogo: la creación queda auditada con el usuario que actuó');
  r := fn_catalogo_guardar(v_ac, 'tipo_documental', v_id, '{"nombre":"Acuerdo de prueba editado"}');
  perform pg_temp.ok(r->>'nombre' = 'Acuerdo de prueba editado', 'catálogo: edición');
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_guardar(%s, 'tipo_documental', null, '{"nombre":"acuerdo de prueba editado"}') $q$, v_ac), 'duplicate key');
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_guardar(%s, 'tipo_documental', %s, '{"estado":"inactivo"}') $q$, v_ac, v_id), '[campo:estado|tipo:no_editable]');
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_guardar(%s, 'documento', null, '{"titulo":"x"}') $q$, v_ac), 'Catálogo no soportado');

  -- Permisos: Dependencia no gestiona catálogos; Archivo Central no gestiona usuarios ni parámetros
  r := fn_catalogo_guardar(v_dep, 'tipo_documental', null, '{"nombre":"No debería"}');
  perform pg_temp.ok((r->>'denegado')::boolean and not exists (select 1 from tipo_documental where nombre = 'No debería'),
                     'catálogo: sin permiso no escribe y responde denegado');
  perform pg_temp.ok(exists (select 1 from auditoria where usuario_id = v_dep and resultado = 'denegado' and recurso_tipo = 'tipo_documental'),
                     'catálogo: el intento denegado queda en la auditoría');
  r := fn_catalogo_guardar(v_ac, 'usuario', v_dep, '{"perfil":"administrador"}');
  perform pg_temp.ok((r->>'denegado')::boolean, 'usuarios: Archivo Central no puede cambiar perfiles');
  r := fn_catalogo_guardar(v_adm, 'usuario', v_dep, '{"perfil":"secretaria_general"}');
  perform pg_temp.ok(r->>'perfil' = 'secretaria_general', 'usuarios: el Administrador asigna el perfil');
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_guardar(%s, 'usuario', null, '{"perfil":"dependencia"}') $q$, v_adm), 'llegan desde NOVA');
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_guardar(%s, 'usuario', %s, '{"email":"x@y.co"}') $q$, v_adm, v_dep), 'no se puede editar');

  -- Inactivar exige motivo y lo guarda en la auditoría
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_estado(%s, 'tipo_documental', %s, 'inactivo', ' ') $q$, v_ac, v_id), '[campo:motivo|tipo:obligatorio]');
  r := fn_catalogo_estado(v_ac, 'tipo_documental', v_id, 'inactivo', 'Ya no se usa');
  perform pg_temp.ok(r->>'estado' = 'inactivo' and exists (select 1 from tipo_documental where id = v_id), 'catálogo: inactivar no borra');
  perform pg_temp.ok(exists (select 1 from auditoria where recurso_tipo = 'tipo_documental' and recurso_id = v_id::text and accion = 'inactivar'
                             and detalle->>'motivo' = 'Ya no se usa' and usuario_id = v_ac), 'catálogo: el motivo queda en la auditoría');
  r := fn_catalogo_estado(v_ac, 'tipo_documental', v_id, 'activo');
  perform pg_temp.ok(r->>'estado' = 'activo', 'catálogo: activar no pide motivo');

  -- Importar: la vista previa no escribe; confirmar inserta las válidas y omite las erróneas
  r := fn_catalogo_importar(v_ac, 'dependencia', format('[
      {"codigo":"901","nombre":"Dependencia Importada A","correo_oficial":"imp.a@uniautonoma.edu.co"},
      {"codigo":"901","nombre":"Repetida en el archivo","correo_oficial":"imp.b@uniautonoma.edu.co"},
      {"codigo":"902","nombre":"Con superior","correo_oficial":"imp.c@uniautonoma.edu.co","dependencia_padre_codigo":"901"},
      {"codigo":"903","nombre":"Superior inexistente","correo_oficial":"imp.d@uniautonoma.edu.co","dependencia_padre_codigo":"999"},
      {"codigo":"904","nombre":"Correo de otra","correo_oficial":"%s"}]', (select correo_oficial from dependencia where codigo = '150'))::jsonb, false);
  perform pg_temp.ok((r->>'validas')::int = 2 and (r->>'con_error')::int = 3, 'importar: la vista previa cuenta 2 válidas y 3 con error');
  perform pg_temp.ok(not exists (select 1 from dependencia where codigo in ('901', '902')), 'importar: la vista previa no escribe nada');
  perform pg_temp.ok((select f->>'campo' from jsonb_array_elements(r->'filas') f where (f->>'fila')::int = 2) = 'codigo'
                     and (select f->>'campo' from jsonb_array_elements(r->'filas') f where (f->>'fila')::int = 4) = 'dependencia_padre_codigo'
                     and (select f->>'campo' from jsonb_array_elements(r->'filas') f where (f->>'fila')::int = 5) = 'correo_oficial',
                     'importar: cada error señala el campo (código repetido, superior inexistente, correo de otra dependencia)');
  r := fn_catalogo_importar(v_ac, 'dependencia', '[{"codigo":"901","nombre":"Dependencia Importada A","correo_oficial":"imp.a@uniautonoma.edu.co"},
      {"codigo":"902","nombre":"Con superior","correo_oficial":"imp.c@uniautonoma.edu.co","dependencia_padre_codigo":"901"},
      {"codigo":"","nombre":"Sin código","correo_oficial":"imp.e@uniautonoma.edu.co"}]'::jsonb, true);
  perform pg_temp.ok((r->>'validas')::int = 2 and (select dependencia_padre_id from dependencia where codigo = '902') = (select id from dependencia where codigo = '901'),
                     'importar: confirmar inserta las válidas y resuelve la superior por código');
  perform pg_temp.ok(not exists (select 1 from dependencia where nombre = 'Sin código'), 'importar: omite la fila sin código');
  r := fn_catalogo_importar(v_dep, 'programa_academico', '[{"nombre":"X","nivel":"pregrado"}]'::jsonb, true);
  perform pg_temp.ok((r->>'denegado')::boolean, 'importar: sin permiso no importa');
  perform pg_temp.debe_fallar(format($q$ select fn_catalogo_importar(%s, 'asunto', '[{"nombre":"x"}]', false) $q$, v_ac), 'Solo se importan');

  -- Parámetros: solo el Administrador; valores fuera de rango se rechazan con mensaje claro
  select clave into v_clave from parametro where tipo = 'entero' and maximo is not null order by clave limit 1;
  r := fn_parametro_guardar(v_ac, v_clave, '1');
  perform pg_temp.ok((r->>'denegado')::boolean, 'parámetros: Archivo Central no los cambia');
  perform pg_temp.debe_fallar(format($q$ select fn_parametro_guardar(%s, %L, '999999') $q$, v_adm, v_clave), '[campo:valor|tipo:rango]');
  perform pg_temp.debe_fallar(format($q$ select fn_parametro_guardar(%s, 'no_existe', '1') $q$, v_adm), '[campo:clave|tipo:existente]');

  -- Plantillas: Archivo Central edita y restablece
  r := fn_plantilla_guardar(v_ac, 'acuse_recibo', 'Recibimos su comunicación {consecutivo}', 'Texto de prueba');
  perform pg_temp.ok(r->>'cuerpo' = 'Texto de prueba', 'plantillas: Archivo Central edita una plantilla');
  r := fn_plantilla_guardar(v_ac, 'acuse_recibo', null, null, true);
  perform pg_temp.ok(r->>'cuerpo' = (select cuerpo_original from plantilla_correo where codigo = 'acuse_recibo'), 'plantillas: restablecer el texto original');
  perform pg_temp.debe_fallar(format($q$ select fn_plantilla_guardar(%s, 'acuse_recibo', 'x', '  ') $q$, v_ac), '[campo:cuerpo|tipo:obligatorio]');

  -- Auditoría: solo quien tiene auditoria.consultar
  r := fn_auditoria_consultar(v_ac);
  perform pg_temp.ok((r->>'denegado')::boolean, 'auditoría: Archivo Central no la consulta');
  r := fn_auditoria_consultar(v_adm, p_recurso_tipo => 'tipo_documental', p_recurso_id => v_id::text);
  perform pg_temp.ok((r->>'total')::int >= 4 and jsonb_array_length(r->'datos') >= 4 and (r->'datos'->0->>'usuario') is not null,
                     'auditoría: el Administrador filtra por recurso y ve quién actuó');

  perform fn_set_usuario_actual(v_ac);   -- restaura el usuario de la sesión de pruebas
end $$;

-- ── Parámetros en lenguaje de usuario (SGD-090) ─────────────────────────────
do $$
begin
  perform pg_temp.ok(not exists (select 1 from parametro where descripcion ~ '(RNF|RF|RN)-AC|\mP-[0-9]+|mockup|tentativo'),
    'SGD-090: las descripciones de parámetros no citan códigos de requisitos ni notas internas');
  perform pg_temp.ok(not exists (select 1 from parametro where coalesce(trim(descripcion), '') = ''),
    'SGD-090: todos los parámetros tienen descripción');
end $$;

-- ── Migración 19: registro histórico de comunicaciones (SGD-044) ────────────
do $$
declare
  v_ac bigint := fn_usuario_actual();
  v_dep bigint;   -- usuario de Dependencia (150), creado abajo
  v_dep150 bigint := (select id from dependencia where codigo = '150');
  v_filas jsonb := '[
    {"tipo":"Recibida","numero_original":"385","fecha":"2023-02-28","asunto":"Invitación a mesa departamental","remitente":"Remitente ficticio","dependencia":"150"},
    {"tipo":"Enviada","numero_original":"12","fecha":"2023-03-05","asunto":"Respuesta a la invitación","destinatario":"Destinatario ficticio"},
    {"tipo":"Recibida","numero_original":"400","fecha":"2023-03-10","asunto":"Solicitud A"},
    {"tipo":"recibida","numero_original":"400","fecha":"2023-04-01","asunto":"Solicitud B"},
    {"tipo":"Correo","numero_original":"1","fecha":"2023-01-01","asunto":"Tipo desconocido"},
    {"tipo":"Interna","numero_original":"7","fecha":"31/02/2023","asunto":"Fecha imposible"},
    {"tipo":"Interna","numero_original":"8","fecha":"2023-05-02","asunto":"Circular","dependencia":"Dependencia inexistente"}
  ]';
  r jsonb;
  v_antes bigint := (select count(*) from comunicacion where origen = 'historico' and anio = 2023);
  c record;
begin
  v_dep := (fn_sincronizar_usuario_nova('{"id":"88888888-8888-8888-8888-888888888888","email":"dep.historico@uniautonoma.edu.co","nombre":"Dep","apellido":"Histórico"}'::jsonb)).id;
  update usuario set perfil = 'dependencia', dependencia_id = v_dep150 where id = v_dep;

  -- Vista previa: resultados por fila sin guardar nada
  r := fn_historico_importar(v_ac, v_filas, false);
  perform pg_temp.ok((r->>'total')::int = 7 and (r->>'nuevas')::int = 3 and (r->>'revisar')::int = 2 and (r->>'errores')::int = 2,
    'SGD-044: vista previa clasifica nuevas, para revisar y con error');
  perform pg_temp.ok((select count(*) from comunicacion where origen = 'historico' and anio = 2023) = v_antes,
    'SGD-044: la vista previa no guarda nada');
  perform pg_temp.ok(r->'filas'->4->>'campo' = 'tipo' and r->'filas'->5->>'campo' = 'fecha',
    'SGD-044: el error de la fila señala el campo');

  -- Confirmar: comunicaciones cerradas, consecutivo del sistema y número original conservado (RN-AC-10)
  r := fn_historico_importar(v_ac, v_filas, true);
  perform pg_temp.ok((r->>'nuevas')::int = 3, 'SGD-044: confirmar crea solo las filas válidas');
  select * into c from comunicacion where tipo = 'ENT' and anio = 2023 and consecutivo_original = '385';
  perform pg_temp.ok(c.consecutivo = 'ENT-2023-900001' and c.estado = 'cerrada' and c.origen = 'historico' and c.dependencia_id = v_dep150,
    'RF-AC-019: histórico cerrado, con consecutivo adaptado y dependencia por código');
  perform pg_temp.ok(exists (select 1 from comunicacion where tipo = 'SAL' and anio = 2023 and consecutivo_original = '12' and comunicacion_entrada_id is null),
    'SGD-044: una salida histórica no necesita entrada enlazada');
  perform pg_temp.ok(r->'filas'->6->>'aviso' like 'No se encontró la dependencia%' and
    (select dependencia_id from comunicacion where tipo = 'INT' and anio = 2023 and consecutivo_original = '8') is null,
    'SGD-044: dependencia desconocida se importa sin dependencia y con aviso');
  perform pg_temp.ok(not exists (select 1 from comunicacion where anio = 2023 and consecutivo_original = '400'),
    'RF-AC-019: número repetido en el mismo año se marca para revisión y no se importa');
  perform pg_temp.ok(exists (select 1 from auditoria where accion = 'importar' and recurso_tipo = 'comunicacion_historico' and usuario_id = v_ac),
    'SGD-044: la importación queda en la auditoría con el usuario');

  -- Idempotencia: el mismo Excel otra vez no duplica
  r := fn_historico_importar(v_ac, v_filas, true);
  perform pg_temp.ok((r->>'nuevas')::int = 0 and (r->>'ya_importadas')::int = 3
    and (select count(*) from comunicacion where origen = 'historico' and anio = 2023) = v_antes + 3,
    'RF-AC-019: importar el mismo Excel dos veces no duplica');
  r := fn_historico_importar(v_ac, '[{"numero_original":"386","fecha":"2023-02-28","asunto":"Otra"}]', true, 'recibidas');
  perform pg_temp.ok(r->'filas'->0->>'consecutivo' = 'ENT-2023-900002', 'SGD-044: tipo para todas las filas y numeración continua del bloque histórico');

  -- Permisos
  r := fn_historico_importar(v_dep, v_filas, true);
  perform pg_temp.ok((r->>'denegado')::boolean and exists (select 1 from auditoria where recurso_tipo = 'comunicacion_historico'
    and accion = 'importar' and resultado = 'denegado' and usuario_id = v_dep), 'SGD-044: Dependencia no importa y el intento queda auditado');

  -- Calendario y lista del mes
  r := fn_historico_calendario(v_ac, 2023);
  perform pg_temp.ok(jsonb_array_length(r->'meses') = 12 and (r->'meses'->1->>'importadas')::int >= 2 and r->'anios' @> '[2023]',
    'RF-AC-019: calendario de 12 meses con importadas');
  r := fn_historico_calendario(v_ac, 2023, 'enviadas');
  perform pg_temp.ok((r->'meses'->2->>'importadas')::int >= 1 and (r->'meses'->1->>'importadas')::int = 0,
    'RF-AC-019: filtro por enviadas');
  r := fn_historico_calendario(v_dep, 2023);
  perform pg_temp.ok((r->'meses'->1->>'total')::int >= 1 and (r->'meses'->4->>'total')::int = 0,
    'SGD-044: Dependencia solo ve el histórico de su dependencia');
  r := fn_historico_mes(v_ac, 2023, 2);
  perform pg_temp.ok((r->>'total')::int >= 2 and r->'filas' @> '[{"consecutivo":"ENT-2023-900001","consecutivo_original":"385"}]',
    'RF-AC-019: lista de comunicaciones del mes');
  perform pg_temp.debe_fallar($q$ select fn_historico_calendario(fn_usuario_actual(), 2023, 'faxes') $q$, 'Tipo no válido');
  perform pg_temp.debe_fallar($q$ select fn_historico_mes(fn_usuario_actual(), 2023, 13) $q$, 'Mes no válido');
  perform fn_set_usuario_actual(v_ac);   -- se restaura el usuario de la sesión de pruebas
end $$;

-- ── Migración 20: archivo navegable y búsqueda avanzada (SGD-032) ───────────
do $$
declare
  v_ac bigint := fn_usuario_actual();
  v_dep110 bigint := (select id from dependencia where codigo = '110');
  v_dep150 bigint := (select id from dependencia where codigo = '150');
  v_as110 bigint := (select id from asunto where dependencia_id = (select id from dependencia where codigo = '110') and nombre = 'Actas');
  v_as150 bigint := (select id from asunto where dependencia_id = (select id from dependencia where codigo = '150') order by id limit 1);
  v_trd110 text := (select t.codigo from asunto a join trd t on t.id = a.trd_id where a.nombre = 'Actas'
                     and a.dependencia_id = (select id from dependencia where codigo = '110'));
  v_udep bigint;
  v_ura bigint;
  r jsonb;
begin
  v_udep := (fn_sincronizar_usuario_nova('{"id":"99999999-0000-4000-8000-000000000001","email":"dep.archivo@uniautonoma.edu.co","nombre":"Dep","apellido":"Archivo"}'::jsonb)).id;
  update usuario set perfil = 'dependencia', dependencia_id = v_dep150 where id = v_udep;
  v_ura := (fn_sincronizar_usuario_nova('{"id":"99999999-0000-4000-8000-000000000002","email":"ra.archivo@uniautonoma.edu.co","nombre":"RA","apellido":"Archivo"}'::jsonb)).id;
  update usuario set perfil = 'registro_academico' where id = v_ura;

  insert into documento (archivo_id, dependencia_id, anio, asunto_id, fecha_documento, origen, estado,
                         tipo_comunicacion, consecutivo, remitente, destinatario, titulo)
  values (pg_temp.nuevo_archivo(repeat('3', 64)), v_dep110, 2025, v_as110, '2025-02-28', 'documento_individual', 'clasificado',
          'ENT', '0385', 'Gobernación Ficticia del Cauca', null, 'Invitación a mesa departamental'),
         (pg_temp.nuevo_archivo(repeat('4', 64)), v_dep150, 2025, v_as150, '2025-03-10', 'documento_individual', 'clasificado',
          'SAL', '12/2025', null, 'Persona Ficticia Uno', 'Certificado de prueba');

  -- Árbol
  r := fn_archivo_arbol(v_ac);
  perform pg_temp.ok(exists (select 1 from jsonb_array_elements(r) n, jsonb_array_elements(n->'anios') y, jsonb_array_elements(y->'asuntos') a
                              where (n->>'dependencia_id')::bigint = v_dep110 and (y->>'anio')::int = 2025
                                and (a->>'asunto_id')::bigint = v_as110 and (a->>'total')::int >= 1),
    'RF-AC-013: el árbol Dependencia → Año → Asunto cuenta los documentos clasificados');
  perform pg_temp.ok(exists (select 1 from jsonb_array_elements(r) n where (n->>'total')::int = 0),
    'RF-AC-013: las dependencias sin documentos también aparecen');
  r := fn_archivo_arbol(v_udep);
  perform pg_temp.ok(jsonb_array_length(r) = 1 and (r->0->>'dependencia_id')::bigint = v_dep150,
    'RF-AC-013: Dependencia solo ve sus carpetas');
  r := fn_archivo_arbol(v_ura);
  perform pg_temp.ok((r->>'denegado')::boolean and exists (select 1 from auditoria where usuario_id = v_ura
    and recurso_tipo = 'archivo' and resultado = 'denegado'), 'SGD-032: sin documentos.consultar no ve el árbol y queda auditado');

  -- Búsqueda
  r := fn_archivo_buscar(v_ac, '{"consecutivo":"385"}');
  perform pg_temp.ok(r->'filas' @> '[{"origen":"documento","titulo":"Invitación a mesa departamental"}]'
                     and r->'filas' @> '[{"origen":"comunicacion","consecutivo_original":"385"}]',
    'RF-AC-014: "385" encuentra el documento y las comunicaciones con ese número');
  r := fn_archivo_buscar(v_ac, '{"consecutivo":"385","dia":28,"mes":2,"alcance":"documentos"}');
  perform pg_temp.ok((r->>'total')::int = 1, 'RF-AC-014: "385 del 28 de febrero" filtra también por la fecha');
  r := fn_archivo_buscar(v_ac, '{"consecutivo":"385","dia":29,"mes":2,"alcance":"documentos"}');
  perform pg_temp.ok((r->>'total')::int = 0, 'RF-AC-014: otra fecha no coincide');
  r := fn_archivo_buscar(v_ac, '{"persona":"ficticia uno"}');
  perform pg_temp.ok(r->'filas' @> '[{"titulo":"Certificado de prueba"}]', 'RF-AC-014: búsqueda por persona (destinatario)');
  r := fn_archivo_buscar(v_ac, '{"persona":"remitente ficticio"}');
  perform pg_temp.ok(r->'filas' @> '[{"origen":"comunicacion"}]', 'RF-AC-014: la búsqueda por persona incluye comunicaciones');
  r := fn_archivo_buscar(v_udep, '{"persona":"gobernación ficticia"}');
  perform pg_temp.ok((r->>'total')::int = 0, 'RF-AC-014: Dependencia no encuentra documentos de otra dependencia');
  r := fn_archivo_buscar(v_ac, format('{"trd":"%s"}', v_trd110)::jsonb);
  perform pg_temp.ok(r->'filas' @> '[{"titulo":"Invitación a mesa departamental"}]' and not (r->'incluye'->>'comunicaciones')::boolean,
    'RF-AC-014: búsqueda por código TRD (solo documentos)');
  r := fn_archivo_buscar(v_ac, '{"tipo":"salida","anio":2025,"alcance":"documentos"}');
  perform pg_temp.ok(r->'filas' @> '[{"titulo":"Certificado de prueba"}]' and not r->'filas' @> '[{"titulo":"Invitación a mesa departamental"}]',
    'RF-AC-014: filtro por tipo');
  r := fn_archivo_buscar(v_ac, '{"anio":2025,"alcance":"documentos"}', 1, 1);
  perform pg_temp.ok(jsonb_array_length(r->'filas') = 1 and (r->>'total')::int >= 2, 'RF-AC-014: resultados paginados');
  r := fn_archivo_buscar(v_ac, '{"persona":"%"}');
  perform pg_temp.ok((r->>'total')::int = 0, 'SGD-032: los comodines del usuario se buscan como texto');
  r := fn_archivo_buscar(v_ura, '{"texto":"acta"}');
  perform pg_temp.ok((r->>'denegado')::boolean, 'SGD-032: sin permisos de consulta la búsqueda se niega');
  perform fn_set_usuario_actual(v_ac);   -- las funciones fijan el usuario que actúa: se restaura el de la sesión
  perform pg_temp.debe_fallar($q$ select fn_archivo_buscar(fn_usuario_actual(), '{"tipo":"fax"}') $q$, 'Tipo no válido');
end $$;

-- ── Auditoría ────────────────────────────────────────────────────────────────
do $$
begin
  perform fn_auditar('consultar', 'historia_academica', '1', '{"motivo":"prueba"}');
  perform fn_auditar('denegado', 'documento', '99', '{}', 'denegado');
  perform pg_temp.ok(exists (select 1 from auditoria where accion = 'denegado' and resultado = 'denegado'), 'RF-AC-023: intento denegado auditado');
  perform pg_temp.ok(exists (select 1 from auditoria where recurso_tipo = 'documento' and accion = 'anular' and usuario_id = fn_usuario_actual()), 'anulación auditada con usuario');
  perform pg_temp.ok(exists (select 1 from auditoria where recurso_tipo = 'documento' and accion = 'actualizar' and valores_previos is not null and valores_nuevos is not null), 'cambios auditados con valores previos y nuevos');
  perform pg_temp.debe_fallar($q$ update auditoria set accion = 'x' $q$, 'RF-AC-023');
  perform pg_temp.debe_fallar($q$ delete from auditoria $q$, 'RF-AC-023');
  perform pg_temp.debe_fallar($q$ truncate auditoria $q$, 'RF-AC-023');
end $$;

-- ── IA ───────────────────────────────────────────────────────────────────────
do $$
begin
  perform pg_temp.debe_fallar($q$ insert into sugerencia_ia (confianza) values (0.9) $q$, 'sugerencia_un_objetivo');
  perform pg_temp.debe_fallar($q$ insert into sugerencia_ia (documento_id, confianza, decision) select id, 0.9, 'aceptada' from documento limit 1 $q$, 'sugerencia_decision_humana');
end $$;

-- ── Seguridad ────────────────────────────────────────────────────────────────
do $$
begin
  perform pg_temp.ok(not exists (select 1 from pg_tables where schemaname = 'public' and not rowsecurity), 'RNF-AC-02: RLS activo en todas las tablas');
end $$;

\echo '>>> Todas las pruebas pasaron. Revirtiendo datos de prueba.'
rollback;
