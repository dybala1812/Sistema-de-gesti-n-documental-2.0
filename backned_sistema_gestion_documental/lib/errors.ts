/**
 * Respuestas HTTP y contrato de errores del backend SGD (RN-AC-15, D-21).
 *
 * Toda respuesta de error es JSON y tiene una de estas dos formas:
 *  - Error de FORMULARIO (4xx: dato inválido, campo faltante, duplicado, permiso, no existe):
 *      { "error": "<descripción para el usuario>", "campo"?: "<campo>", "tipo"?: "<categoría>" }
 *    Sin número de error de sistema y sin consecutivo (un fallo de validación no consume
 *    consecutivo, RN-AC-08).
 *  - Error de SISTEMA (5xx: fallo interno, base de datos, configuración, servicio externo):
 *      { "error": "<número>", "motivo": "<por qué>", "consecutivo"?: "ENT-AAAA-NNNNNN" }
 *    `consecutivo` solo aparece si el fallo es del sistema de consecutivos (el contador
 *    falló o el número ya existía).
 *
 * Este archivo no importa nada: así se prueba directo con `node --test` (tests/errores.test.mjs).
 */

/** Catálogo de números de error de sistema. El número va en `error`; el texto, en `motivo`. */
export const ERRORES_SISTEMA = {
  INTERNO: { numero: "1000", motivo: "Ocurrió un error inesperado en el servidor" },
  BASE_DATOS: { numero: "1001", motivo: "La base de datos no pudo completar la operación" },
  MIGRACION: { numero: "1002", motivo: "Falta aplicar una migración en la base de datos" },
  CONFIGURACION: { numero: "1003", motivo: "Falta configuración en el servidor" },
  SERVICIO_EXTERNO: { numero: "1004", motivo: "Un servicio externo (n8n o NOVA) no respondió" },
  ALMACENAMIENTO: { numero: "1005", motivo: "No se pudo leer o guardar el archivo en el almacenamiento" },
  CONSECUTIVO: { numero: "1010", motivo: "No se pudo generar el consecutivo" },
  CONSECUTIVO_EXISTENTE: { numero: "1011", motivo: "El consecutivo generado ya existía" },
} as const;

export type ClaveErrorSistema = keyof typeof ERRORES_SISTEMA;

export type ErrorFormulario = { error: string; campo?: string; tipo?: string };
export type ErrorSistema = { error: string; motivo: string; consecutivo?: string };

/** Datos adicionales que aceptan las funciones de error (compatibles con las rutas existentes). */
export type ApiError = {
  error?: string;
  detalle?: string;
  codigo?: string;
  campo?: string;
  tipo?: string;
  /** Solo errores de sistema: clave del catálogo (si no viene, se deduce de `codigo`). */
  sistema?: ClaveErrorSistema;
  /** Solo errores de sistema del contador de consecutivos. */
  consecutivo?: string;
};

const ES_PRODUCCION = typeof process !== "undefined" && process.env?.NODE_ENV === "production";

export function jsonResponse<T>(data: T, status = 200): Response {
  return Response.json(data, { status });
}

/** Error de formulario: descripción clara y, si aplica, el campo a marcar. */
export function errorFormulario(descripcion: string, status = 400, extra: { campo?: string; tipo?: string } = {}): Response {
  const cuerpo: ErrorFormulario = { error: descripcion };
  if (extra.campo) cuerpo.campo = extra.campo;
  if (extra.tipo) cuerpo.tipo = extra.tipo;
  return Response.json(cuerpo, { status: status >= 400 && status < 500 ? status : 400 });
}

/**
 * Error de sistema: número del catálogo y motivo. `detalle` se agrega al motivo cuando ayuda a
 * resolverlo (p. ej. qué migración falta); el detalle técnico interno solo se muestra fuera de producción.
 */
export function errorSistema(clave: ClaveErrorSistema, status = 500, extra: { detalle?: string; consecutivo?: string; interno?: string } = {}): Response {
  const { numero, motivo } = ERRORES_SISTEMA[clave];
  let texto: string = motivo;
  if (extra.detalle) texto += `: ${extra.detalle}`;
  if (extra.interno && !ES_PRODUCCION) texto += ` (${extra.interno})`;
  const cuerpo: ErrorSistema = { error: numero, motivo: texto };
  if (extra.consecutivo && (clave === "CONSECUTIVO" || clave === "CONSECUTIVO_EXISTENTE")) cuerpo.consecutivo = extra.consecutivo;
  return Response.json(cuerpo, { status: status >= 500 ? status : 500 });
}

/** Deduce el error de sistema a partir del código de PostgreSQL / PostgREST. */
export function claveSistemaPorCodigo(codigo?: string): ClaveErrorSistema {
  if (!codigo) return "INTERNO";
  if (codigo === "PGRST202" || codigo === "PGRST205" || codigo === "42883" || codigo === "42P01") return "MIGRACION";
  if (/^(PGRST|[0-9A-Z]{5}$)/.test(codigo)) return "BASE_DATOS";
  return "INTERNO";
}

/**
 * Respuesta de error con la forma del contrato según el código HTTP. La usan todas las rutas:
 * 4xx → error de formulario (la descripción incluye `detalle` si lo hay); 5xx → error de sistema.
 */
export function errorResponse(message: string, status = 400, extra: Partial<ApiError> = {}): Response {
  if (status >= 500) {
    const clave = extra.sistema ?? claveSistemaPorCodigo(extra.codigo);
    // El mensaje de la ruta explica el caso; el motivo del catálogo da el contexto.
    return errorSistema(clave, status, {
      detalle: message && message !== ERRORES_SISTEMA[clave].motivo ? message + (extra.detalle && !message.includes(extra.detalle) ? `. ${extra.detalle}` : "") : extra.detalle,
      consecutivo: extra.consecutivo,
    });
  }
  const descripcion = extra.detalle && !message.includes(extra.detalle) ? `${message}: ${extra.detalle}` : message;
  return errorFormulario(descripcion, status, { campo: extra.campo, tipo: extra.tipo });
}

export function unauthorized(message = "No autorizado"): Response {
  return errorFormulario(message, 401);
}

export function forbidden(message = "Acceso denegado"): Response {
  return errorFormulario(message, 403);
}

export function notFound(message = "Recurso no encontrado"): Response {
  return errorFormulario(message, 404);
}

/**
 * Columna que causó un duplicado, desde el `details` de PostgreSQL. Con claves compuestas
 * (p. ej. asunto: dependencia_id + nombre) devuelve la que el usuario escribió, no el id.
 *   "Key (dependencia_id, lower(nombre::text))=(3, actas) already exists." → "nombre"
 */
export function columnaDuplicada(details?: string | null): string | undefined {
  const m = /Key \((.+?)\)=\(/.exec(details ?? "");
  if (!m) return undefined;
  const columnas = m[1]
    .split(",")
    .map((c) => c.trim().replace(/^lower\(/i, "").replace(/::\w+/g, "").replace(/\)+$/, "").trim())
    .filter(Boolean);
  return [...columnas].reverse().find((c) => !c.endsWith("_id")) ?? columnas[columnas.length - 1];
}

/** Consecutivo repetido (fallo del contador, error de sistema) a partir del `details`. */
export function consecutivoDuplicado(details?: string | null): string | undefined {
  const m = /Key \((?:consecutivo|tipo, anio, numero)\)=\(([^)]*)\)/.exec(details ?? "");
  if (!m) return undefined;
  const valor = m[1].trim();
  // (ENT, 2026, 123) → ENT-2026-000123
  const partes = /^(ENT|SAL|INT),\s*(\d{4}),\s*(\d+)$/.exec(valor);
  return partes ? `${partes[1]}-${partes[2]}-${partes[3].padStart(6, "0")}` : valor;
}

export function handleError(error: unknown): Response {
  if (error instanceof Response) return error;
  // Errores internos de Next.js (p. ej. NEXT_PRERENDER_INTERRUPTED al leer headers en el build):
  // deben propagarse para que Next marque la ruta como dinámica; no son fallos de la API.
  const digest = (error as { digest?: unknown } | null)?.digest;
  if (typeof digest === "string" && /^(NEXT_|DYNAMIC_SERVER_USAGE)/.test(digest)) throw error;

  // Errores de validación con campo/tipo (p. ej. SolicitudInvalida de lib/n8n.ts).
  const campo = (error as { campo?: string } | null)?.campo;
  const tipo = (error as { tipo?: string } | null)?.tipo;
  if (error instanceof Error && (campo || tipo)) {
    return errorFormulario(error.message, 400, { campo, tipo });
  }

  // Errores con código HTTP propio (p. ej. lib/archivos.ts: 413 tamaño, 415 formato, 404 no existe).
  // Sin esto n8n recibiría 500 y reintentaría el mismo correo indefinidamente.
  const status = (error as { status?: unknown } | null)?.status;
  if (error instanceof Error && typeof status === "number" && status >= 400 && status < 500) {
    return errorFormulario(error.message, status);
  }

  // Servicio externo que respondió con error (lib/n8nWebhook.ts). El detalle técnico solo fuera de producción.
  const servicio = (error as { servicio?: string } | null)?.servicio;
  if (error instanceof Error && servicio) {
    const statusExterno = (error as { statusExterno?: number }).statusExterno;
    return errorSistema("SERVICIO_EXTERNO", 502, {
      detalle: `${servicio} respondió${statusExterno ? ` ${statusExterno}` : " con error"}`,
      interno: error.message,
    });
  }
  if (error instanceof Error && (error as { configuracion?: boolean }).configuracion) {
    return errorSistema("CONFIGURACION", 500, { detalle: error.message });
  }

  // Archivo que no está en el almacenamiento local.
  if ((error as { code?: string } | null)?.code === "ENOENT") {
    return errorSistema("ALMACENAMIENTO", 500);
  }
  // Configuración de Supabase incompleta (assertSupabaseConfig).
  if (error instanceof Error && /SUPABASE|Supabase no está configurado|variables de entorno/i.test(error.message)) {
    return errorSistema("CONFIGURACION", 500, { detalle: error.message });
  }

  console.error("[backend error]", error);
  return errorSistema("INTERNO", 500, { interno: error instanceof Error ? error.message : undefined });
}
