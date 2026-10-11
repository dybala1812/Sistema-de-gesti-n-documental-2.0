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
