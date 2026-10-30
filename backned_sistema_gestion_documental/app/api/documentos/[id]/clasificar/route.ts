/**
 * POST /api/documentos/[id]/clasificar
 * Body: { asunto_id?, tipo?, consecutivo?, fecha? (AAAA-MM-DD), anio?, remitente?, destinatario?,
 *         carro?, estante?, bandeja?, caja?, carpeta?, ubicacion_id?, observaciones?, clasificar?: boolean (por defecto true) }
 * Guarda los datos de un documento de "Por clasificar" y, con clasificar=true, lo clasifica (RF-AC-011):
 * sale de Por clasificar y queda en Clasificados y en el Archivo (Dependencia → Año → Asunto).
 * Con clasificar=false solo guarda lo escrito. También sirve para reclasificar.
 * Permiso documentos.clasificar (el intento denegado queda auditado). Función SQL: fn_documento_clasificar (migración 21).
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { rpc } from "../../../../../lib/catalogos";
import { SolicitudInvalida, idRuta, parseBody } from "../../../../../lib/n8n";
import { errorResponse, handleError, jsonResponse } from "../../../../../lib/errors";

const MIGRACION = "20261021000000_clasificar_documento.sql";

/** Claves que la función SQL sabe cambiar; las demás se ignoran. */
const CLAVES = [
  "asunto_id", "tipo", "consecutivo", "fecha", "anio", "remitente", "destinatario",
  "carro", "estante", "bandeja", "caja", "carpeta", "ubicacion_id", "observaciones",
] as const;

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const documentoId = idRuta(await params);
    const b = await parseBody(request);

    const datos: Record<string, unknown> = {};
    for (const k of CLAVES) {
      if (!(k in b)) continue;
      const v = b[k];
      if (v !== null && typeof v !== "string" && typeof v !== "number") {
        throw new SolicitudInvalida(`${k} debe ser texto o número`, k, "formato");
      }
      datos[k] = v;
    }
    if ("clasificar" in b && typeof b.clasificar !== "boolean") {
      throw new SolicitudInvalida("clasificar debe ser true o false", "clasificar", "formato");
    }

    const documento = await rpc<Record<string, unknown>>("fn_documento_clasificar", {
      p_usuario_id: usuario.id,
      p_documento_id: documentoId,
      p_datos: datos,
      p_clasificar: b.clasificar !== false,
    }, MIGRACION);

    return jsonResponse({ ok: true, estado: documento.estado, documento });
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}
