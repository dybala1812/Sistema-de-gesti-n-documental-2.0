# Arquitectura — SGD · Módulo Archivo Central

Fuente: F-02 v1.1 §2.1, §2.4, §5.2 y RN-AC-08/14. Lo marcado **(propuesta)** es derivación del equipo/IA y no está en la fuente; validar contra el F-03 (Arquitectura y diseño) y `decisiones.md`.

## Vista general

```text
             ┌──────────────────────┐        ┌────────────────────────┐
 Usuarios ─► │ Frontend web (React) │        │ PWA móvil (escaneo)    │
             └──────────┬───────────┘        └───────────┬────────────┘
                        │ HTTPS (sesión / JWT)           │
                        ▼                                ▼
             ┌──────────────────────────────────────────────────────┐
             │ Backend de la aplicación (tecnología: P-11)          │
             │  - permisos por perfil y dependencia (RF-AC-023)     │
             │  - recepción/servido de archivos (carpetas locales,  │
             │    id por archivo, hash SHA-256)                     │
             │  - auditoría                                         │
             └───────┬───────────────────────────────┬──────────────┘
                     │                               │
                     ▼                               ▼
     ┌──────────────────────────────┐   ┌──────────────────────────────┐
     │ Supabase (PostgreSQL)        │   │ Carpetas locales de archivos │
     │  tablas del módulo,          │   │  archivos (PDF/JPG/PNG/XLSX) │
     │  función de consecutivos,    │   │  BD referencia cada uno por id│
     │  funciones de estado         │   └──────────────▲───────────────┘
     └──────────────▲───────────────┘                  │ HTTP (sube archivo,
                    │ escritura directa                │ recibe id)  
             ┌──────┴──────────────────────────────────┴──┐
             │ n8n (flujos F1–F11)                        │──► Buzón institucional
             └──────────────────────┬─────────────────────┘    (Google / M365: P-02)
                                    └──► Servicio de IA (opcional, P-13)
```

## Flujos n8n

**n8n solo maneja la Bandeja de comunicaciones (F1–F6, D-15).** Tablas, columnas y consultas SQL por flujo: `backned_sistema_gestion_documental/n8n/TABLAS_N8N.md`.

Detalle en `D:\trabajo_practica profesional\Flujos n8n — Archivo Central.docx` (pendiente de copiar a `fuentes/`).

| Flujo | Función | Requisitos |
|---|---|---|
| F1 | Correo entrante: lee el buzón, descarta auto-respuestas/rebotes/duplicados (Message-ID), crea comunicación ENT, guarda adjuntos (archivo + id), acuse de recibo; rama de respuesta de dependencia (etiqueta `[SGD …]` o `In-Reply-To`). | RF-AC-015, 016 |
| F2 | Remitir a dependencia. | RF-AC-016 |
| F3 | Responder al remitente (crea SAL y cierra). | RF-AC-017 |
| F4 | Recordatorios diarios en días hábiles + resumen a AC. | RF-AC-018 |
| F5 | Envío de correo (servicio común). | RF-AC-015–018 |
| F6 | Manejo de errores. | Transversal |
| ~~F7~~ | Inventario FUID → **lo hace el backend** (D-15). | RF-AC-009, 010 |
| ~~F8~~ | Cargas digitales → **backend** (D-15). | RF-AC-008, 010 |
| ~~F9~~ | Historias académicas → **backend** (D-15). | RF-AC-021 |
| ~~F10~~ | Importación del histórico → **backend** (D-15). | RF-AC-019 |
| ~~F11~~ | IA → **backend** (D-15). | RF-AC-012 |

Reglas para los flujos:
- Idempotentes: reprocesar un correo, lote o Excel no duplica (Message-ID, hash, consecutivo+año).
- No marcar un correo como leído hasta que esté registrado en la BD (RNF-AC-04).
- Consecutivos siempre vía la función de BD; nunca calcularlos en n8n.
- Un error en un elemento no detiene el lote; se registra en el informe (RF-AC-007).
- Exportar cada flujo en JSON al repositorio y documentarlo (RNF-AC-09).

## Entidades principales

**Esquema implementado:** `backned_sistema_gestion_documental/supabase/migrations/` (ver su `README.md`). La tabla siguiente es el resumen original; si difiere, manda el SQL.

| Entidad | Campos clave | Notas |
|---|---|---|
| dependencia | código ú, nombre, padre_id, responsable, correo_oficial ú, estado | |
| trd_serie | código ú, nombre, padre_id, años_gestión, años_central, disposición_final, estado | serie/subserie |
| asunto | dependencia_id, nombre, trd_id, descripción, estado | ú (dependencia_id, nombre) |
| tipo_documental / programa / ubicacion | nombre ú, estado (programa: nivel) | |
| usuario | nova_user_id ú, email, nombre, cédula, datos_nova, dependencia_id, perfil (enum 5, NULL = sin acceso), estado | copia sincronizada desde NOVA; sin contraseña (D-13) |
| parametro / plantilla_correo | clave, valor / código, asunto, cuerpo con variables | |
| lote_carga | tipo, usuario, estado, totales (aceptados, duplicados, errores), informe | |
| documento | dependencia_id, año, asunto_id?, tipo_id?, consecutivo, fecha, caja, carpeta, archivo_id, estado (por_clasificar/clasificado/anulado), lote_id, transferencia_id? | ú (expediente, hash) |
| transferencia | dependencia_id, año, tipo (física/digital), funcionario_entrega, acta_ruta, estado (en proceso/recibida/anulada) | |
| inventario_item | transferencia_id, caja, carpeta_tomo, asunto, fecha_ini, fecha_fin, folios, rango_consecutivos | del FUID |
| comunicacion | tipo (ENT/SAL/INT), año, número, consecutivo, consecutivo_original?, message_id ú, remitente, asunto, estado, dependencia_id?, fecha_limite, entrada_id? (para SAL), por_escalar, n_recordatorios | |
| comunicacion_evento | comunicacion_id, tipo (remisión, respuesta, devolución, recordatorio…), fecha, usuario, detalle | historial/línea de pasos |
| adjunto | propietario (documento/comunicación), archivo_id | |
| archivo | id (UUID), ruta_relativa, nombre_original, hash SHA-256, tamaño, mime, fecha, usuario | referencia única al archivo en disco; la unicidad (expediente, hash) se valida al enlazarlo |
| contador_consecutivo | tipo, año, último | usado por la función atómica |
| estudiante / historia_academica | documento ú, nombres, apellidos; estado (activa/retirado/graduado), año, programa_id | |
| sugerencia_ia | recurso, valor sugerido, confianza, justificación, decisión (aceptada/modificada/descartada), usuario | |
| auditoria | usuario, acción, recurso, fecha, valores_previos, valores_nuevos, resultado (ok/denegado) | append-only |

## Almacenamiento de archivos

Los archivos se guardan **localmente en carpetas** y la base de datos los referencia por **id** (D-02, RN-AC-14).

1. Al subir, el backend calcula el SHA-256, genera un `id` (UUID) y guarda el archivo como `<id>.<ext>`.
2. Inserta la fila en `archivo` (id, ruta relativa, nombre original, hash, tamaño, tipo).
3. El documento, adjunto o historia guarda solo `archivo_id`.
4. Para ver o descargar, el cliente pide `/archivos/<id>`; el backend valida permisos, resuelve la ruta y sirve el archivo.

Estructura de carpetas (propuesta, la raíz se configura por variable de entorno):

```text
<RAIZ_ARCHIVOS>/
  documentos/<codigo_dependencia>/<año>/<id>.pdf
  transferencias/<codigo_dependencia>/<año>/<id>.xlsx      (FUID, actas)
  comunicaciones/<año>/<consecutivo>/<id>.<ext>            (adjuntos de correo)
  historias/<estado>/<año>/<nivel>/<programa>/<id>.pdf
```

La carpeta es solo organización física: la fuente de verdad de la clasificación es la BD. Si un documento se reclasifica, se actualiza la BD y no hace falta mover el archivo.

## Contrato de errores de API (D-21, RN-AC-15)

Toda respuesta 4xx/5xx es JSON. No se envía HTML ni un mensaje genérico de NOVA que tape el motivo.

**Error de sistema** (5xx: fallo interno, de BD, de configuración, de un servicio externo o del contador de consecutivos):

```json
{ "error": "1011", "motivo": "El consecutivo generado ya existía", "consecutivo": "ENT-2026-000041" }
```

`consecutivo` **solo** se incluye en los errores 1010/1011 (fallo del contador o número ya existente). Fuera de producción el motivo agrega entre paréntesis el detalle técnico para depurar; en producción no.

**Error de formulario** (4xx: validación, duplicado, campo faltante, permiso, no existe):

```json
{ "error": "Ya existe un registro con ese nombre en esta dependencia", "campo": "nombre", "tipo": "duplicado" }
```

Sin número de error y sin consecutivo: un fallo de validación **no consume** consecutivo (el contador sube dentro de la misma transacción y se revierte con el error; prueba en `pruebas_reglas.sql`). El frontend (`sgdApi.ts` › `mensajeErrorSgd`) muestra la descripción tal cual y, si viene `campo`, marca ese campo; un error de sistema se muestra como `Error 1001: <motivo>`.

**Catálogo de errores de sistema** (`backned_sistema_gestion_documental/lib/errors.ts` › `ERRORES_SISTEMA`; pruebas en `tests/errores.test.mjs`, `npm test`):

| Número | Clave | Motivo | Cuándo |
|---|---|---|---|
| 1000 | INTERNO | Ocurrió un error inesperado en el servidor | Excepción no prevista |
| 1001 | BASE_DATOS | La base de datos no pudo completar la operación | Error de PostgreSQL/PostgREST que no es de validación |
| 1002 | MIGRACION | Falta aplicar una migración en la base de datos | Función o tabla inexistente (PGRST202, 42883, 42P01) |
| 1003 | CONFIGURACION | Falta configuración en el servidor | Variables de entorno de Supabase u otras ausentes |
| 1004 | SERVICIO_EXTERNO | Un servicio externo (n8n o NOVA) no respondió | Webhook de n8n o perfil de NOVA caído |
| 1005 | ALMACENAMIENTO | No se pudo leer o guardar el archivo en el almacenamiento | Archivo ausente en disco (sin exponer la ruta) |
| 1010 | CONSECUTIVO | No se pudo generar el consecutivo | Falla de `fn_siguiente_consecutivo` |
| 1011 | CONSECUTIVO_EXISTENTE | El consecutivo generado ya existía | Choque de unicidad en `comunicacion.consecutivo` |

Un número nuevo se agrega al catálogo (sin reutilizar números) y a la prueba que verifica que no se repiten.

## Seguridad de datos (propuesta)

- Activar **RLS** en todas las tablas de Supabase; n8n usa una credencial de servicio guardada solo en n8n.
- Los archivos nunca se sirven por ruta pública: descarga mediante endpoint con sesión o enlace temporal firmado (RNF-AC-02).
- La auditoría solo admite INSERT (sin UPDATE/DELETE, ni siquiera para ADM).
