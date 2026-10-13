# APIs del backend que consumen los flujos de n8n

> **Estado (2026-10-07): las 21 implementadas.** Las 19 de datos en `backned_sistema_gestion_documental/app/api/n8n/**/route.ts` (fábrica común en `lib/n8n.ts`); las funciones SQL en `database/supabase/migrations/20261007000900_n8n_funciones.sql` (probadas con `database/scripts/probar_local.sh`). Las 2 de archivos ya existían.
> - Errores de reglas de negocio (`RN-AC-xx`, `RF-AC-xx`) → **409** con el texto original (F1 detecta `RN-AC-09`).
> - Validación de la petición → **400** `{ error: "Datos inválidos", detalle }`. Token inválido → **401**.
> - En #9, #10 y #12 el usuario se envía como `usuario` (también se acepta `usuario_id`).
> - Además existe `POST /api/n8n/comunicaciones` (versión anterior de #4, devuelve `creada`); los flujos deben usar #4.

**Total: 19 APIs de datos + 2 de archivos = 21.**

## Convenciones (aplican a las 21)

- Base: `https://BACKEND_URL_AQUI` (se cambia en los nodos HTTP).
- Autenticación: `Authorization: Bearer N8N_SERVICE_TOKEN` (la misma credencial «Backend SGD» que ya usan los nodos de archivos).
- Cuerpo y respuesta en JSON. Las llamadas son `POST` salvo `GET /api/archivos/{id}`.
- **Respuesta siempre un objeto**, aunque no se inserte nada (por ejemplo `{ "id": null }`). Una respuesta vacía o `[]` hace que n8n no genere ítems y el flujo se detenga. Las dos que devuelven lista están marcadas como *array*.
- Errores: código 4xx/5xx con el mensaje en el cuerpo. n8n lo recibe en `error`.
- Cada API puede llamar por dentro a la función SQL que ya tienes (`supabase.rpc('n8n_...')`), así no se reescribe la lógica.

## F1 · Correo entrante (7)

| # | Endpoint | Función SQL actual | Cuerpo | Respuesta |
|---|---|---|---|---|
| 1 | `/api/n8n/correos/estado` | `n8n_estado_correo` | `message_id, asunto, in_reply_to, de_correo` | `{ ya_procesado, comunicacion_id, dependencia_id, dependencia_nombre, es_propio }` |
| 2 | `/api/n8n/correos/rebote` | `n8n_registrar_rebote` | `ids[], de, asunto` | `{ asociados, auditado }` |
| 3 | `/api/n8n/correos/respuesta-dependencia` | `n8n_registrar_respuesta_dependencia` | `comunicacion_id, de_correo, asunto, cuerpo, message_id, recibido_en, archivo_ids[], adjuntos_omitidos[]` | `{ id, consecutivo, estado }` |
| 4 | `/api/n8n/correos/nuevo` | `n8n_registrar_correo_nuevo` | `message_id, de_nombre, de_correo, asunto, cuerpo, recibido_en, in_reply_to, archivo_ids[], adjuntos_omitidos[]` | `{ id, consecutivo }` |
| 5 | `/api/n8n/correos/sugerencia` | `n8n_guardar_sugerencia` | `comunicacion_id, detalle` (objeto o `null`) | `{ id }` (`{ id: null }` si `detalle` es null) |
| 6 | `/api/n8n/correos/sin-asociar` | `n8n_guardar_sin_asociar` | `message_id, in_reply_to, de_nombre, de_correo, asunto, cuerpo, recibido_en, motivo, posible_comunicacion_id, adjuntos[]` | `{ insertados }` |
| 7 | `/api/n8n/correos/error-acuse` | `n8n_registrar_error_acuse` | `comunicacion_id, error` | `{ id }` |

Notas:
- **#3:** si la transición de estado no es válida, responder 4xx con el texto `RN-AC-09` en el mensaje. F1 lo detecta y manda el correo a «sin asociar».
- **#6:** valores de `motivo` que usa F1: `otro`, `etiqueta_no_coincide`, `sin_etiqueta`, `remitente_externo_sin_etiqueta`.

## F2 · Remitir y devolver (3 propias)

| # | Endpoint | Función SQL actual | Cuerpo | Respuesta |
|---|---|---|---|---|
| 8 | `/api/n8n/remisiones/leer` | `n8n_leer_remision` | `comunicacion_id, dependencia_id` (puede ser null) | `{ id, tipo, estado, consecutivo, asunto, dep_id, dependencia, dep_estado, correo_oficial, plazo_defecto, adjuntos[] }`; si no existe, `{ id: null }` |
| 9 | `/api/n8n/remisiones/remitir` | `n8n_remitir` | `usuario, comunicacion_id, dependencia_id, plazo, message_id, mensaje` | objeto con el resultado |
| 10 | `/api/n8n/remisiones/devolver` | `n8n_devolver` | `usuario, comunicacion_id, message_id, dependencia_id, mensaje` | objeto con el resultado |

## F3 · Responder al remitente (2 propias)

| # | Endpoint | Función SQL actual | Cuerpo | Respuesta |
|---|---|---|---|---|
| 11 | `/api/n8n/respuestas/leer-entrada` | `n8n_leer_entrada` | `comunicacion_id` | `{ id, tipo, estado, consecutivo, asunto, remitente_nombre, remitente_correo, adjuntos: [{ archivo_id, de_dependencia }] }`; si no existe, `{ id: null }` |
| 12 | `/api/n8n/respuestas/responder` | `n8n_responder` | `usuario, entrada_id, asunto, cuerpo, message_id, archivos[]` | objeto con el resultado |

En F2 y F3 el objeto de #9, #10 y #12 se devuelve tal cual a quien llamó el webhook.

## Compartidas por F2, F3, F4 y F6 (3)

| # | Endpoint | Usada por | Función SQL actual | Cuerpo | Respuesta |
|---|---|---|---|---|---|
| 13 | `/api/n8n/errores/envio` | F2, F3, F4 | `n8n_registrar_error_envio` | `usuario, comunicaciones[], dependencia, detalle` | objeto |
| 14 | `/api/n8n/auditoria` | F2, F3 | `n8n_auditar` | `flujo, detalle` | objeto |
| 15 | `/api/n8n/auditoria/error-flujo` | F6 | `n8n_auditar_error_flujo` | `flujo, ejecucion, nodo, mensaje, url` | `{ ok: true }` |

## F4 · Recordatorios (4 propias)

| # | Endpoint | Función SQL actual | Cuerpo | Respuesta |
|---|---|---|---|---|
| 16 | `/api/n8n/recordatorios/dia-habil` | `n8n_es_dia_habil` | `{}` | `{ habil: true/false }` |
| 17 | `/api/n8n/recordatorios/pendientes` | `n8n_recordatorios_pendientes` | `{}` | *array*, una fila por dependencia: `{ dependencia_id, nombre, correo_oficial, pendientes: [{ id, consecutivo, asunto, fecha_limite, dias_vencida }] }` |
| 18 | `/api/n8n/recordatorios/registrar` | `n8n_registrar_recordatorios` | `ids[], message_id` | objeto |
| 19 | `/api/n8n/recordatorios/resumen-dia` | `n8n_resumen_dia` | `{}` | *array*, una fila por comunicación activa: `{ buzon, consecutivo, estado, vencida, por_escalar, dependencia, dias_desde_recepcion }` |

## F5 · Envío de correo (1, agregada 2026-10-12)

| # | Endpoint | Función SQL | Cuerpo | Respuesta |
|---|---|---|---|---|
| 22 | `/api/n8n/correos/enviado` | `n8n_registrar_correo_enviado` (migración 14) | `message_id, para, asunto, cuerpo, plantilla, comunicacion_id?, consecutivos[], archivo_ids[], enviado_en` | `{ id, comunicacion_id, duplicado }` |

Guarda una copia de cada correo que envía F5 para verlo desde el historial de la comunicación (`GET /api/comunicaciones/{id}/eventos/{eventoId}/correo`). Idempotente por `message_id`. Si `comunicacion_id` no viene, se toma del primer consecutivo. En F5 va después de «Resultado del envío» con *On Error → Continue*: el correo ya salió y no debe reenviarse. Nodos listos para pegar: `flujos n8n/F5_nodos_copia_correo_PEGAR.json`.

## Archivos (2, ya existentes)

| # | Endpoint | Usada por | Descripción |
|---|---|---|---|
| 20 | `POST /api/archivos` | F1 | Recibe el adjunto (`multipart`: `archivo`, `categoria`, `contexto`) y devuelve el `archivo_id`. |
| 21 | `GET /api/archivos/{id}` | F5 | Devuelve el binario del adjunto. |

## Lo que sigue en el nodo Supabase

Estas 4 lecturas/inserciones simples siguen con el nodo Supabase y no cuentan arriba: leer `dependencia` activas (F1), crear el evento de acuse en `comunicacion_evento` (F1), leer `plantilla_correo` (F5) y leer el parámetro `buzon_archivo_central` (F6). Si las quieres también por API, serían 4 más (25 en total).
