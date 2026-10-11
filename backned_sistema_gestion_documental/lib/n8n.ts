/**
 * Utilidades comunes de las rutas /api/n8n/* (flujos de la Bandeja de comunicaciones).
 *
 * Convenciones (APIs_backend_n8n.md):
 *  - Autenticación: Authorization: Bearer <N8N_SERVICE_TOKEN>.
 *  - Cuerpo y respuesta JSON. La respuesta es SIEMPRE un objeto (p. ej. {"id": null}),
 *    salvo las rutas marcadas como lista, que devuelven un array.
 *  - Errores: 4xx/5xx con { error, detalle? }. Los errores de reglas de negocio de la
 *    base (RN-AC-xx / RF-AC-xx) se devuelven como 409 con el texto original, para que
 *    el flujo pueda reconocerlos (p. ej. RN-AC-09 → "sin asociar").
 *  - Cada ruta llama a su función SQL n8n_* (migración 20261007000900_n8n_funciones.sql).
 */
import { NextRequest } from "next/server";
import { esServicioN8N } from "./auth";
import { supabase, assertSupabaseConfig } from "./supabase";
import { errorResponse, handleError, jsonResponse, unauthorized } from "./errors";

type Cuerpo = Record<string, unknown>;

/** Error de validación de la petición (→ 400).
 *  `campo`: nombre del campo que falló.
 *  `tipo`: categoría del error (obligatorio, tipo, rango, formato, lista, etc.).
 */
export class SolicitudInvalida extends Error {
  constructor(
    message: string,
    public campo?: string,
    public tipo?: string
  ) {
    super(message);
  }
}

// ── Lectores de campos del cuerpo ───────────────────────────────────────────

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const leer = {
  /** Texto o null (cadena vacía → null). */
  texto(b: Cuerpo, campo: string, obligatorio = false): string | null {
    const v = b[campo];
    if (v === undefined || v === null || v === "") {
      if (obligatorio) throw new SolicitudInvalida(`${campo} es obligatorio`, campo, "obligatorio");
      return null;
    }
    if (typeof v !== "string" && typeof v !== "number") throw new SolicitudInvalida(`${campo} debe ser texto`, campo, "tipo");
    return String(v);
  },
  /** Entero positivo o null. */
  entero(b: Cuerpo, campo: string, obligatorio = false): number | null {
    const v = b[campo];
    if (v === undefined || v === null || v === "") {
      if (obligatorio) throw new SolicitudInvalida(`${campo} es obligatorio`, campo, "obligatorio");
      return null;
    }
    const n = Number(v);
    if (!Number.isInteger(n) || n <= 0) throw new SolicitudInvalida(`${campo} debe ser un entero positivo`, campo, "rango");
    return n;
  },
  /** Lista de enteros positivos ([] si no viene). */
  enteros(b: Cuerpo, campo: string, obligatorio = false): number[] {
    const v = b[campo] ?? [];
    if (!Array.isArray(v)) throw new SolicitudInvalida(`${campo} debe ser una lista`, campo, "tipo");
    if (obligatorio && v.length === 0) throw new SolicitudInvalida(`${campo} es obligatorio`, campo, "obligatorio");
    return v.map((x) => {
      const n = Number(x);
      if (!Number.isInteger(n) || n <= 0) throw new SolicitudInvalida(`${campo} debe contener enteros positivos`, campo, "lista");
      return n;
    });
  },
  /** Lista de textos ([] si no viene). */
  textos(b: Cuerpo, campo: string): string[] {
    const v = b[campo] ?? [];
    if (!Array.isArray(v)) throw new SolicitudInvalida(`${campo} debe ser una lista`, campo, "tipo");
    return v.map(String);
  },
  /** Lista de uuid (archivo_id) ([] si no viene). */
  uuids(b: Cuerpo, campo: string): string[] {
    const v = b[campo] ?? [];
    if (!Array.isArray(v) || !v.every((x) => typeof x === "string" && UUID.test(x))) {
      throw new SolicitudInvalida(`${campo} debe ser una lista de uuid (archivo_id)`, campo, "formato");
    }
    return v as string[];
  },
  /** Fecha ISO 8601 o null. */
  fecha(b: Cuerpo, campo: string): string | null {
    const v = leer.texto(b, campo);
    if (v !== null && Number.isNaN(Date.parse(v))) throw new SolicitudInvalida(`${campo} debe ser una fecha ISO 8601`, campo, "formato");
    return v;
  },
  /** Valor JSON tal cual (objeto, lista o null). */
  json(b: Cuerpo, campo: string): unknown {
    return b[campo] ?? null;
  },
};

// ── Fábrica de rutas ────────────────────────────────────────────────────────

type Opciones = {
  /** Nombre de la función SQL. */
  funcion: string;
  /** Arma los parámetros p_* de la función a partir del cuerpo. */
  parametros?: (b: Cuerpo) => Record<string, unknown>;
  /** true = la respuesta es un array (una fila por elemento). */
  lista?: boolean;
  /** Objeto a devolver cuando la función no devuelve filas. */
  vacio?: Record<string, unknown>;
  /** Transforma el resultado antes de responder (p. ej. boolean → objeto). */
  mapear?: (data: unknown) => unknown;
};

/** Normaliza el resultado de supabase.rpc a objeto (o array si `lista`). */
function normalizar(data: unknown, opciones: Opciones): unknown {
  if (opciones.mapear) return opciones.mapear(data);
  if (opciones.lista) return Array.isArray(data) ? data : data == null ? [] : [data];
  if (Array.isArray(data)) return data[0] ?? opciones.vacio ?? {};
  if (data === null || data === undefined) return opciones.vacio ?? {};
  if (typeof data !== "object") return { resultado: data };
  return data;
}

/** Crea el handler POST de una ruta /api/n8n/*. */
export function rutaN8N(opciones: Opciones) {
  return async function POST(request: NextRequest): Promise<Response> {
    try {
      if (!esServicioN8N(request)) return unauthorized("Token de servicio de n8n inválido");

      let cuerpo: Cuerpo = {};
      const textoCuerpo = await request.text();
      if (textoCuerpo.trim() !== "") {
        try {
          const parsed: unknown = JSON.parse(textoCuerpo);
          if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
            return errorResponse("El cuerpo debe ser un objeto JSON", 400);
          }
          cuerpo = parsed as Cuerpo;
        } catch {
          return errorResponse("El cuerpo debe ser JSON válido", 400);
        }
      }

      const params = opciones.parametros ? opciones.parametros(cuerpo) : {};
      assertSupabaseConfig();

      const { data, error } = await supabase.rpc(opciones.funcion, params);
      if (error) return errorDeBase(error);

      return jsonResponse(normalizar(data, opciones));
    } catch (err) {
      // El motivo va también en `error`: n8n solo muestra ese texto en el mensaje del nodo.
      if (err instanceof SolicitudInvalida) {
        return errorResponse(`Datos inválidos: ${err.message}`, 400, {
          detalle: err.message,
          campo: err.campo,
          tipo: err.tipo,
        });
      }
      return handleError(err);
    }
  };
}

const ETIQUETA_ERROR = /^\[campo:([^|\]]+)\|tipo:([^|\]]+)\]\s*/;

function extraerCampoTipo(mensaje: string): { campo?: string; tipo?: string; mensaje: string } {
  const m = ETIQUETA_ERROR.exec(mensaje);
  if (!m) return { ...inferirCampoTipo(mensaje), mensaje };
  return {
    campo: m[1],
    tipo: m[2],
    mensaje: mensaje.replace(ETIQUETA_ERROR, ""),
  };
}

/** Fallback para mensajes de error de funciones SQL que aún no usan la etiqueta [campo:|tipo:]. */
function inferirCampoTipo(mensaje: string): { campo?: string; tipo?: string } {
  if (/Archivos que no son adjuntos/.test(mensaje)) return { campo: "archivos", tipo: "adjuntos" };
  if (/no es una comunicaci[óo]n de entrada/.test(mensaje)) return { campo: "entrada_id", tipo: "tipo" };
  if (/solo se responde una comunicaci[óo]n/.test(mensaje)) return { campo: "entrada_id", tipo: "estado" };
  if (/no existe/.test(mensaje) && /comunicaci[óo]n/i.test(mensaje)) return { campo: "entrada_id", tipo: "existente" };
  return {};
}

/** Extrae campo/tipo del detalle de PostgreSQL (FK, unique, not null). */
function inferirCampoTipoDetalle(detalle?: string | null): { campo?: string; tipo?: string } {
  if (!detalle) return {};
  const fk = /Key \(([^)]+)\)=\([^)]*\) is not present in table/.exec(detalle);
  if (fk) return { campo: fk[1], tipo: "existente" };
  const dup = /Key \(([^)]+)\)=\([^)]*\) already exists/.exec(detalle);
  if (dup) return { campo: dup[1], tipo: "duplicado" };
  return {};
}

/** Traduce un error de PostgreSQL/PostgREST a una respuesta HTTP. */
function errorDeBase(error: { message: string; code?: string; details?: string | null }): Response {
  const { mensaje, campo, tipo } = extraerCampoTipo(error.message);
  const deDetalle = inferirCampoTipoDetalle(error.details);
  const extra: Record<string, unknown> = { detalle: error.details ?? undefined, codigo: error.code };
  if (campo || deDetalle.campo) extra.campo = campo ?? deDetalle.campo;
  if (tipo || deDetalle.tipo) extra.tipo = tipo ?? deDetalle.tipo;

  // Reglas de negocio lanzadas por triggers/funciones (P0001): RN-AC-09, RF-AC-017, etc.
  if (/\b(RN|RF)-AC-\d+/.test(mensaje)) return errorResponse(mensaje, 409, extra);
  switch (error.code) {
    case "23505": // único
      return errorResponse(mensaje, 409, extra);
    case "23503": // FK / no existe
    case "23502": // not null
    case "23514": // check
    case "22023": // dato inválido (lanzado por las funciones)
    case "22P02": // texto con formato inválido (uuid, número…)
    case "22007": // fecha inválida
      return errorResponse(mensaje, 400, extra);
    case "PGRST202": // función no encontrada (migración no aplicada)
      return errorResponse(`La función SQL no existe en la base: ${mensaje}`, 500, extra);
    default:
      return errorResponse(mensaje, 500, extra);
  }
}

/** Parsea el body de una petición manual (no rutaN8N) y devuelve un objeto JSON. */
export async function parseBody(request: NextRequest): Promise<Cuerpo> {
  const texto = await request.text();
  if (texto.trim() === "") return {};
  try {
    const parsed: unknown = JSON.parse(texto);
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new SolicitudInvalida("El cuerpo debe ser un objeto JSON", "body", "formato");
    }
    return parsed as Cuerpo;
  } catch {
    throw new SolicitudInvalida("El cuerpo debe ser JSON válido", "body", "formato");
  }
}

/** Extrae y valida un id numérico positivo de los parámetros de ruta. */
export function idRuta(params: { [key: string]: string | string[] | undefined }, campo = "id"): number {
  const raw = Array.isArray(params[campo]) ? params[campo][0] : params[campo];
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) {
    throw new SolicitudInvalida(`${campo} debe ser un entero positivo`, campo, "rango");
  }
  return n;
}

/**
 * Usuario de Archivo Central que disparó la acción desde la Bandeja (para la auditoría).
 * Acepta `usuario` o `usuario_id`. Obligatorio en remitir, devolver y responder.
 */
export function usuario(b: Cuerpo): number {
  const id = leer.entero(b, "usuario") ?? leer.entero(b, "usuario_id");
  if (id === null) throw new SolicitudInvalida("usuario es obligatorio (quién actúa, para la auditoría)", "usuario", "obligatorio");
  return id;
}
