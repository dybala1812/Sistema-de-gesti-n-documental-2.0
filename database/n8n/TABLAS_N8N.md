# Flujos n8n — Bandeja de comunicaciones · SGD Archivo Central

Referencia para construir los flujos n8n del **circuito de comunicaciones por correo** (pantalla *Bandeja de comunicaciones*, RF-AC-015 a RF-AC-018).
Esquema completo: `../supabase/migrations/`. Si este documento y el SQL difieren, manda el SQL.

## Alcance

n8n **solo** maneja la Bandeja de comunicaciones (D-15):

| Flujo | Qué hace | RF |
|---|---|---|
| **F1** Correo entrante | Lee el buzón, registra correos nuevos con su consecutivo, guarda adjuntos, envía acuse de recibo y asocia las respuestas de las dependencias | RF-AC-015, 016 |
| **F2** Remitir | Envía la comunicación a la dependencia que debe atenderla (y la devolución si la respuesta está incompleta) | RF-AC-016 |
| **F3** Responder | Envía la respuesta final al remitente, crea la salida SAL y cierra la entrada | RF-AC-017 |
| **F4** Recordatorios | Cada día hábil recuerda a las dependencias las vencidas y envía el resumen a Archivo Central | RF-AC-018 |
| **F5** Envío de correo | Subflujo común: arma el correo desde la plantilla y lo envía | — |
| **F6** Errores | Registra los fallos de cualquier flujo en la auditoría | RNF-AC-04 |

**No pasan por n8n** (los hace el backend directamente): centro de cargas, documentos, transferencias e inventario FUID, historias académicas, importación del registro histórico (RF-AC-019) y sugerencias de IA.

---

## Arquitectura: dos destinos

```text
                ┌── 1. Adjuntos del correo ──► BACKEND ──► guarda en carpeta comunicaciones/…
                │      HTTP POST /api/archivos              + inserta fila en "archivo"
n8n ────────────┤                                           └─► responde { archivo_id }
                │
                └── 2. Datos (filas) ──────► SUPABASE (nodo Postgres), usando ese archivo_id
```

- **Adjuntos → backend.** Es el único que escribe en las carpetas y en la tabla `archivo` (D-02). n8n nunca guarda archivos en disco.
- **Tablas → Supabase directo** (D-03). n8n escribe `comunicacion`, `comunicacion_evento`, `comunicacion_adjunto` y `correo_sin_asociar`. Las reglas de negocio están en la base (triggers y funciones), así que se cumplen igual.
- **Orden siempre**: primero subir los adjuntos y obtener los `archivo_id`; después escribir las filas que los usan.

## Subir un adjunto al backend

> El backend aún no existe (tecnología: P-11). Este es el **contrato** que debe cumplir; n8n se construye contra él.

```http
POST {BACKEND_URL}/api/archivos
Authorization: Bearer {N8N_SERVICE_TOKEN}
Content-Type: multipart/form-data

archivo   = <binario del adjunto>                           (obligatorio)
categoria = comunicaciones                                  (obligatorio)
contexto  = {"anio": 2026, "message_id": "<abc@mail>"}      (opcional, JSON: subcarpeta)
```

Qué hace el backend:
1. Valida el token de n8n (token de servicio propio, distinto de los usuarios de NOVA).
2. Valida extensión y tamaño contra `parametro.formatos_permitidos` y `parametro.tamano_maximo_archivo_mb`.
3. Calcula SHA-256, genera el `uuid` y guarda en `<RAIZ_ARCHIVOS>/comunicaciones/<anio>/<uuid>.<ext>`.
4. Inserta la fila en `archivo` y responde.

Respuesta `201 Created`:
```json
{
  "archivo_id": "3f2a9c1e-…",
  "nombre_original": "Certificado de notas.pdf",
  "hash_sha256": "9b74c9897bac770ffc029102a200c5de…",
  "tamano_bytes": 248133,
  "mime": "application/pdf",
  "ruta_relativa": "comunicaciones/2026/3f2a9c1e-….pdf"
}
```

Errores:

| HTTP | Cuándo | Qué hace n8n |
|---|---|---|
| `400` | falta el archivo o la categoría | F6 |
| `401` | token inválido | detener el flujo y avisar (F6) |
| `413` | el adjunto supera el tamaño máximo | registrar la comunicación **sin ese adjunto** y anotarlo en un evento `nota` |
| `415` | formato no permitido | igual que 413 |
| `5xx` | fallo del servidor | reintentar (máx. 3) y luego F6; **no marcar el correo como leído** para que se reprocese |

Descargar un adjunto (para reenviarlo en F2 / F3):
```http
GET {BACKEND_URL}/api/archivos/{archivo_id}
Authorization: Bearer {N8N_SERVICE_TOKEN}
→ 200 con el binario (Content-Type y Content-Disposition con el nombre original)
```

Credenciales en n8n (nunca en el repo): `BACKEND_URL`, `N8N_SERVICE_TOKEN`, conexión Postgres de Supabase, cuenta del buzón institucional.

## Reglas para todos los flujos

1. **Tablas**: nodo *Postgres* con la credencial de servicio de Supabase. La API pública (`anon`) está cerrada. **Adjuntos**: nodo *HTTP Request* al backend.
2. **Quién actúa**: si el flujo lo dispara un usuario desde la Bandeja (Remitir, Devolver, Responder), ejecutar primero, en la misma transacción:
   ```sql
   select set_config('app.usuario_id', '{{ $json.usuario_id }}', true);
   ```
   Si es automático (F1, F4), omitirlo: queda registrado como "sistema".
3. **Consecutivos**: nunca calcularlos en n8n. Los asigna la base al insertar en `comunicacion`.
4. **Sin DELETE**: bloqueado en todas las tablas. Para descartar una comunicación se **anula** con motivo.
5. **Idempotencia**: el mismo correo leído dos veces no se duplica (Message-ID). Usar siempre las funciones indicadas.
6. **No marcar el correo como leído** hasta que la comunicación (y sus adjuntos) quede registrada.
7. **F3 solo registra después de enviar con éxito**: si el envío falla, el estado no cambia.
8. Los cuerpos de correo se guardan como **texto plano**; no guardar ni mostrar HTML sin sanitizar.

---

## Resumen por flujo

| Flujo | Lee | Escribe | Funciones |
|---|---|---|---|
| **F1** | `comunicacion`, `comunicacion_evento`, `dependencia`, `plantilla_correo`, `parametro` | `comunicacion`, `comunicacion_adjunto`, `comunicacion_evento`, `correo_sin_asociar` (+ `archivo` vía backend) | `fn_registrar_correo_entrante`, `fn_buscar_comunicacion_respondida` |
| **F2** | `comunicacion`, `comunicacion_adjunto`, `dependencia`, `plantilla_correo` | `comunicacion`, `comunicacion_evento` | `fn_remitir_comunicacion` |
| **F3** | `comunicacion`, `comunicacion_adjunto`, `plantilla_correo` | `comunicacion`, `comunicacion_adjunto`, `comunicacion_evento` | `fn_responder_remitente` |
| **F4** | `comunicacion`, `dependencia`, `plantilla_correo`, `parametro`, `dia_festivo`, `v_bandeja_comunicaciones` | `comunicacion`, `comunicacion_evento` | `fn_es_dia_habil`, `fn_comunicaciones_a_recordar`, `fn_registrar_recordatorio` |
| **F5** | `plantilla_correo` | — | — |
| **F6** | — | `auditoria` | `fn_auditar` |

---

## Tablas

Notación: **ú** = único · **FK** = llave foránea · *auto* = lo llena la base (no enviarlo).

### `comunicacion` — F1, F2, F3, F4

| Columna | Tipo | Notas |
|---|---|---|
| `id` | bigint | *auto* |
| `tipo` | enum `ENT` · `SAL` · `INT` | entrada, salida, interno |
| `anio`, `numero` | smallint, integer | *auto* |
| `consecutivo` | text ú | *auto* → `ENT-2026-000001` |
| `origen` | enum `correo` · `manual` · `historico` | n8n usa `correo` |
| `estado` | enum | `nueva` · `remitida` · `respondida_dependencia` · `devuelta` · `cerrada` · `anulada` |
| `message_id` | text ú | Message-ID del correo (evita duplicados) |
| `in_reply_to` | text | encabezado In-Reply-To |
| `remitente_nombre`, `remitente_correo` | text | en ENT |
| `destinatario_nombre`, `destinatario_correo` | text | en SAL |
| `asunto` | text | obligatorio |
| `cuerpo` | text | texto plano |
| `fecha_recepcion` | timestamptz | |
| `dependencia_id` | bigint FK `dependencia` | a quién se remitió |
| `fecha_limite` | date | plazo; lo calcula `fn_remitir_comunicacion` en días hábiles |
| `comunicacion_entrada_id` | bigint FK `comunicacion` | una SAL apunta a su ENT |
| `n_recordatorios`, `ultimo_recordatorio_en`, `por_escalar` | | *auto* vía `fn_registrar_recordatorio` |
| `anulado_motivo` | text | obligatorio para anular |
| `cerrado_en`, `anulado_en`, `anulado_por`, `creado_en`, `actualizado_en` | | *auto* |

Estados (la base rechaza cualquier otra transición):

```text
nueva ──F2 remitir──► remitida ──F1 respuesta──► respondida_dependencia ──F3 responder──► cerrada
                                     ▲                     │
                                     └──── devuelta ◄──────┘ F2 devolver
nueva / remitida / respondida_dependencia / devuelta ──anular (con motivo)──► anulada
```

### `comunicacion_evento` — historial / línea de pasos

| Columna | Tipo | Notas |
|---|---|---|
| `comunicacion_id` | bigint FK | |
| `tipo` | enum | `recepcion` · `acuse_recibo` · `remision` · `respuesta_dependencia` · `devolucion` · `respuesta_remitente` · `recordatorio` · `marcada_escalar` · `asociacion_manual` · `anulacion` · `nota` · `error_envio` |
| `estado_anterior`, `estado_nuevo` | enum | |
| `dependencia_id` | bigint FK | |
| `message_id` | text | Message-ID del correo **enviado** en este paso (permite asociar respuestas por In-Reply-To) |
| `detalle` | jsonb | |
| `usuario_id` | bigint FK | null = sistema |

> Los cambios de estado crean su evento solos. n8n solo inserta a mano: `acuse_recibo`, `error_envio` y `nota`.

### `comunicacion_adjunto`

| Columna | Tipo | Notas |
|---|---|---|
| `comunicacion_id` | bigint FK | |
| `evento_id` | bigint FK `comunicacion_evento` | opcional: adjunto de la respuesta de la dependencia |
| `archivo_id` | uuid FK `archivo` | el que devolvió `POST /api/archivos` |
| ú (`comunicacion_id`, `archivo_id`) | | |

### `correo_sin_asociar` — F1

| Columna | Tipo | Notas |
|---|---|---|
| `message_id` | text ú | |
| `in_reply_to` | text | |
| `de_nombre`, `de_correo` | text | `de_correo` obligatorio |
| `asunto`, `cuerpo` | text | |
| `recibido_en` | timestamptz | obligatorio |
| `motivo` | text | `sin_etiqueta` · `etiqueta_no_coincide` · `remitente_externo_sin_etiqueta` · `otro` |
| `posible_comunicacion_id` | bigint FK | sugerencia para el usuario |
| `adjuntos` | uuid[] | ids de `archivo` |
| `resuelto…` | | los llena el usuario desde la pantalla "Correos sin asociar" |

### `archivo` — solo lectura para n8n

La escribe **solo el backend** (vía `POST /api/archivos`). n8n usa el `id` (uuid) que recibe.

### Tablas de solo lectura

| Tabla / vista | Columnas útiles | Flujos |
|---|---|---|
| `dependencia` | `id`, `codigo`, `nombre`, `correo_oficial`, `estado` | F1 (¿el remitente es una dependencia?), F2, F4 |
| `plantilla_correo` | `codigo` (`acuse_recibo`, `remision`, `devolucion`, `respuesta`, `recordatorio`, `resumen`), `asunto`, `cuerpo` | F1–F5 |
| `parametro` | `clave`, `valor` | todos |
| `dia_festivo` | `fecha` | F4 (vía `fn_es_dia_habil`) |
| `v_bandeja_comunicaciones` | `consecutivo`, `estado`, `dependencia`, `vencida`, `por_escalar`, `dias_desde_recepcion` | F4 (resumen diario) |

Parámetros:

| Clave | Uso |
|---|---|
| `buzon_archivo_central` | buzón que lee F1 (`correspondencia@uniautonoma.edu.co`, por confirmar) |
| `tamano_maximo_archivo_mb`, `formatos_permitidos` | los valida el backend al subir adjuntos |
| `plazo_respuesta_dias_habiles` | F2 (plazo por defecto) |
| `recordatorio_cada_dias_habiles`, `max_recordatorios_antes_escalar` | F4 (ya los usan las funciones) |

Variables de las plantillas: `{consecutivo}` `{nombre}` `{asunto}` `{dependencia}` `{fecha}` `{plazo}` `{respuesta}`.
Todo correo que envía el sistema lleva en el asunto la etiqueta **`[SGD <consecutivo>]`**: así F1 reconoce las respuestas.

---

## Consultas por flujo

### F1 — Correo entrante (cada pocos minutos; registro en ≤ 5 min)

1. Leer correos no leídos del buzón. Descartar respuestas automáticas y rebotes.
2. Por cada adjunto → `POST /api/archivos` (`categoria=comunicaciones`) → juntar los `archivo_id` en `$archivo_ids`.
3. Decidir si es respuesta de una dependencia o correo nuevo:

```sql
-- ¿Responde a una comunicación? (etiqueta [SGD ENT-2026-000001] o In-Reply-To)
select fn_buscar_comunicacion_respondida($asunto, $in_reply_to) as comunicacion_id;

-- ¿El remitente es una dependencia?
select id, nombre from dependencia where lower(correo_oficial) = lower($de_correo) and estado = 'activo';
```

**A. Respuesta asociada** (la función devolvió un id):
```sql
update comunicacion set estado = 'respondida_dependencia' where id = $comunicacion_id;

insert into comunicacion_adjunto (comunicacion_id, evento_id, archivo_id)
select $comunicacion_id,
       (select max(id) from comunicacion_evento where comunicacion_id = $comunicacion_id and tipo = 'respuesta_dependencia'),
       unnest($archivo_ids::uuid[]);
```
→ avisar a Archivo Central.

**B. Parece respuesta pero no se pudo asociar** (remitente es dependencia o asunto empieza con `RE:`, y la función devolvió null):
```sql
insert into correo_sin_asociar (message_id, in_reply_to, de_nombre, de_correo, asunto, cuerpo, recibido_en, motivo, adjuntos)
values ($message_id, $in_reply_to, $de_nombre, $de_correo, $asunto, $cuerpo, $recibido_en, 'sin_etiqueta', $archivo_ids::uuid[])
on conflict (message_id) do nothing;
```

**C. Correo nuevo → endpoint del backend** (idempotente por Message-ID):

```http
POST {BACKEND_URL}/api/n8n/comunicaciones
Authorization: Bearer {N8N_SERVICE_TOKEN}
Content-Type: application/json

{
  "message_id": "<CAJx9k…@mail.gmail.com>",          (obligatorio)
  "remitente_nombre": "Luisa Fernanda Ante",
  "remitente_correo": "luisa.fernanda@estudiantes.uniautonoma.edu.co",   (obligatorio)
  "asunto": "Solicitud de certificado de notas",
  "cuerpo": "Buenos días… (texto plano)",
  "recibido_en": "2026-10-07T08:12:00-05:00",         (ISO 8601; si falta, ahora)
  "in_reply_to": null,
  "adjuntos": ["3f2a9c1e-…", "8b1d…"]                  (archivo_id de POST /api/archivos)
}
```

| Respuesta | Significado | Qué hace n8n |
|---|---|---|
| `201` `{comunicacion_id, consecutivo, estado:"nueva", creada:true, adjuntos}` | Creada | enviar acuse con el `consecutivo` y marcar leído |
| `200` `{…, creada:false}` | Ya estaba registrada (reintento) | no reenviar acuse; marcar leído |
| `400` | Datos inválidos o un `archivo_id` no existe (`detalle` explica) | revisar el nodo; F6 |
| `401` | Token de n8n inválido | detener y avisar (F6) |
| `5xx` | Fallo del servidor | reintentar; **no** marcar leído |

Por dentro llama a `fn_registrar_comunicacion_n8n` (migración 08): comunicación + adjuntos en una sola transacción.
→ F5 envía el acuse (`plantilla_correo` `acuse_recibo`) y luego:
```sql
insert into comunicacion_evento (comunicacion_id, tipo, message_id) values ($id, 'acuse_recibo', $message_id_acuse);
```

4. Marcar el correo como leído **solo si** A, B o C terminaron bien.

### F2 — Remitir (lo dispara el botón "Remitir" de la Bandeja)

```sql
select set_config('app.usuario_id', $usuario_id, true);

select c.consecutivo, c.asunto, d.nombre as dependencia, d.correo_oficial
from comunicacion c, dependencia d
where c.id = $comunicacion_id and d.id = $dependencia_id;

-- adjuntos elegidos para reenviar → GET /api/archivos/{archivo_id} por cada uno
select archivo_id from comunicacion_adjunto where comunicacion_id = $comunicacion_id;
```
→ F5 envía con la plantilla `remision` y `[SGD <consecutivo>]` en el asunto. Después de enviar:
```sql
select * from fn_remitir_comunicacion($comunicacion_id, $dependencia_id, $plazo_dias_habiles, $message_id_enviado, $mensaje);
```

**Devolver** (respuesta incompleta, plantilla `devolucion`):
```sql
update comunicacion set estado = 'devuelta' where id = $comunicacion_id;
update comunicacion_evento set message_id = $message_id_enviado
 where id = (select max(id) from comunicacion_evento where comunicacion_id = $comunicacion_id and tipo = 'devolucion');
```

### F3 — Responder al remitente (botón "Enviar respuesta")

```sql
select set_config('app.usuario_id', $usuario_id, true);

-- adjuntos de la respuesta de la dependencia → GET /api/archivos/{archivo_id}
select ad.archivo_id
from comunicacion_adjunto ad
join comunicacion_evento ev on ev.id = ad.evento_id
where ad.comunicacion_id = $entrada_id and ev.tipo = 'respuesta_dependencia';
```
→ F5 envía con la plantilla `respuesta`. **Solo si el envío fue exitoso**:
```sql
select id, consecutivo from fn_responder_remitente($entrada_id, $asunto, $cuerpo, $message_id_enviado);
insert into comunicacion_adjunto (comunicacion_id, archivo_id) select $salida_id, unnest($archivo_ids::uuid[]);
```
Si el envío falló (el estado no cambia; la pantalla permite reintentar):
```sql
insert into comunicacion_evento (comunicacion_id, tipo, detalle)
values ($entrada_id, 'error_envio', jsonb_build_object('error', $error));
```

### F4 — Recordatorios (todos los días a primera hora)

```sql
select fn_es_dia_habil(current_date);   -- si es false, terminar

-- pendientes agrupados → UN correo por dependencia (plantilla recordatorio)
select r.dependencia_id, d.nombre, d.correo_oficial,
       json_agg(json_build_object('id', r.comunicacion_id, 'consecutivo', r.consecutivo, 'asunto', r.asunto,
                                  'fecha_limite', r.fecha_limite, 'dias_vencida', r.dias_vencida)) as pendientes
from fn_comunicaciones_a_recordar() r
join dependencia d on d.id = r.dependencia_id
group by r.dependencia_id, d.nombre, d.correo_oficial;
```
Por cada comunicación incluida en un correo enviado:
```sql
select fn_registrar_recordatorio($comunicacion_id, $message_id_enviado);   -- al 3.er recordatorio marca por_escalar
```
Resumen diario para Archivo Central (plantilla `resumen`):
```sql
select estado,
       count(*)                            as total,
       count(*) filter (where vencida)     as vencidas,
       count(*) filter (where por_escalar) as por_escalar
from v_bandeja_comunicaciones
where estado in ('nueva', 'remitida', 'respondida_dependencia', 'devuelta')
group by estado;
```

### F5 — Envío de correo (subflujo)

```sql
select asunto, cuerpo from plantilla_correo where codigo = $codigo;
```
Reemplazar las variables, adjuntar los binarios descargados del backend, enviar desde el buzón institucional y devolver el **Message-ID** del correo enviado al flujo que lo llamó (se guarda en `comunicacion_evento.message_id`).

### F6 — Errores

```sql
select fn_auditar('error_flujo', 'n8n', $nombre_flujo,
                  jsonb_build_object('ejecucion', $execution_id, 'nodo', $nodo, 'error', $mensaje), 'error');
```

---

## Errores que n8n debe reconocer

| Mensaje / restricción | Significado | Qué hacer |
|---|---|---|
| `comunicacion_message_id_key` | correo ya registrado | ignorar (`fn_registrar_correo_entrante` ya lo maneja) |
| `correo_sin_asociar_message_id_key` | ya está en "sin asociar" | ignorar |
| `RN-AC-09: transición inválida` | cambio de estado no permitido | no reintentar; avisar a Archivo Central |
| `RF-AC-016: para remitir se requiere dependencia y plazo` | faltan datos de remisión | corregir la llamada |
| `RF-AC-017` | se intentó responder una comunicación que no está en `respondida_dependencia` | no enviar el correo |
| `RN-AC-12` | se intentó borrar | usar anulación |
