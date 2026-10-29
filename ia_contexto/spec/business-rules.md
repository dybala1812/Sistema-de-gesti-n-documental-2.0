# Reglas de negocio — SGD · Módulo Archivo Central

Fuente: `ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx` §6 (v1.1, 2026-10-07). Explícitas, numeradas y sin ambigüedad. **Son vinculantes**: ningún código puede violarlas.

| ID | Regla | Requisitos | Implementación sugerida (no vinculante) |
|---|---|---|---|
| RN-AC-01 | El archivo se organiza en **Dependencia → Año → Asunto**. Cada documento pertenece a **un solo** asunto. | RF-AC-001, 003, 011, 013 | FK única `documento.asunto_id`; el árbol se construye con esos tres niveles. |
| RN-AC-02 | El catálogo de asuntos se define **por dependencia** y cada asunto se vincula a un **código TRD**. | RF-AC-002, 003, 011 | Único (`dependencia_id`, `nombre`); `asunto.trd_id` obligatorio. |
| RN-AC-03 | Los documentos permanecen **2 años** en el archivo de gestión. Cada año la dependencia transfiere hasta **año actual − 2** (en 2026, hasta 2024). | RF-AC-009, 010 | Validación en backend con el parámetro "años mínimos" (RF-AC-006); bloquea confirmar. |
| RN-AC-04 | Los documentos se transfieren ordenados por serie, en orden cronológico, foliados y descritos. El **inventario (FUID) y el acta los elabora la dependencia**. | RF-AC-009, 010 | El sistema valida el FUID; no lo genera. |
| RN-AC-05 | Transferencia **física**: no se escanea, se guarda el inventario. Transferencia **digital**: se cargan todos los archivos. | RF-AC-009, 010 | Tipo de transferencia determina el flujo (F7 vs F7+F8). |
| RN-AC-06 | Historias de estudiantes **activos** las gestiona Registro Académico; al **graduarse o retirarse** pasan a custodia de Archivo Central. | RF-AC-020 | Permisos por estado de la historia (RLS/guard). |
| RN-AC-07 | Las historias se organizan por **Estado → Año → Nivel → Programa**, estudiantes en **orden alfabético**. | RF-AC-020, 021 | Orden por apellidos/nombre en consultas del árbol. |
| RN-AC-08 | Comunicaciones de tipo **entrada (ENT), salida (SAL) o interno (INT)**. Consecutivos secuenciales **por tipo**, **reinician cada año** y se generan con una **función atómica de la BD**. Formato `TIPO-AAAA-NNNNNN`. | RF-AC-015, 017, 019 | Función PostgreSQL con bloqueo de fila sobre tabla de contadores (tipo, año). Nunca generar en el cliente ni en n8n. |
| RN-AC-09 | Estados de una comunicación: **Nueva, Remitida, Respondida por dependencia, Devuelta** (activas); **Cerrada, Anulada** (inactivas). **Solo se cierra al enviar la respuesta al remitente.** | RF-AC-015 a 018 | Transiciones validadas en una función/servicio único de cambio de estado. |
| RN-AC-10 | Los consecutivos **históricos** se adaptan al formato del sistema y se **conserva el número original**. | RF-AC-019 | Columna `consecutivo_original`. |
| RN-AC-11 | Un archivo con el **mismo hash dentro del mismo expediente** es duplicado y no se registra. | RF-AC-007, 008, 010, 021 | Restricción única (expediente, hash SHA-256). |
| RN-AC-12 | **No hay borrado físico** desde el sistema: solo anulación con motivo y auditoría. | RF-AC-001–005, 023, 024 | Sin endpoints DELETE para entidades de negocio; estado `anulado`/`inactivo`; auditoría append-only. |
| RN-AC-13 | La **IA nunca clasifica sola** y **no se aplica a historias académicas**. | RF-AC-010, 012, 020 | La sugerencia se guarda aparte; solo una acción humana escribe la clasificación. |
| RN-AC-14 | Los archivos se **guardan localmente en carpetas**; la BD (Supabase) registra cada archivo con un **id** que lo referencia (más ruta relativa, hash y metadatos). | RF-AC-008 | Tabla `archivo`; `documento.archivo_id` / `adjunto.archivo_id`; nombre en disco = id; nunca binarios en la BD ni en Supabase Storage. |
| RN-AC-15 | Toda respuesta de error de la API es **JSON**. Error de **sistema**: `{ "error": "<número>", "motivo": "<por qué>" }` y, **solo** si el fallo es de sistema (p. ej. función atómica de consecutivos), se puede incluir `consecutivo`. Error de **formulario**: `{ "error": "<descripción>", "campo"?: "…" }` — sin número de error de sistema y **sin** consecutivo. Un fallo de validación **no consume** consecutivo (RN-AC-08). | Transversal, RN-AC-08 | `lib/errors.ts`; catálogo de números de error de sistema; el frontend muestra `motivo` o `error` sin sustituirlo por un texto genérico de HTTP. |

## Transiciones válidas de una comunicación

| Desde | Acción | Hacia | Quién |
|---|---|---|---|
| — | Correo entrante registrado (F1) | Nueva | Sistema |
| Nueva | Remitir (F2) | Remitida | AC |
| Remitida / Devuelta | Respuesta de dependencia recibida (F1) | Respondida por dependencia | Sistema |
| Respondida por dependencia | Devolver | Devuelta | AC |
| Respondida por dependencia | Enviar respuesta al remitente (F3) con éxito | Cerrada | AC |
| Nueva / Remitida / Respondida / Devuelta | Anular (con motivo) | Anulada | AC |

Cualquier otra transición es inválida y debe rechazarse. "Por escalar" es una **marca** (no un estado) que se pone tras el 3.er recordatorio.
