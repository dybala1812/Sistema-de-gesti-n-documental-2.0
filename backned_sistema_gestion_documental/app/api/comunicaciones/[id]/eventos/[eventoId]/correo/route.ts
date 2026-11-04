/**
 * GET /api/comunicaciones/[id]/eventos/[eventoId]/correo
 * Devuelve el correo de un paso del historial (recibido o enviado) para verlo en pantalla.
 * 404 con el motivo cuando ese paso no tiene correo guardado.
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeVerDependencia } from "../../../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../../../lib/comunicaciones";
import { SinCorreo, obtenerCorreoDeEvento } from "../../../../../../../lib/correos";
import { SolicitudInvalida, idRuta } from "../../../../../../../lib/n8n";
import { errorResponse, forbidden, handleError, jsonResponse, notFound } from "../../../../../../../lib/errors";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; eventoId: string }> },
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const p = await params;
    const comunicacionId = idRuta(p);
    const eventoId = idRuta(p, "eventoId");

    const comunicacion = await obtenerComunicacion(comunicacionId);
    if (!comunicacion) return notFound("Comunicación no encontrada");
    if (!puedeVerDependencia(usuario, comunicacion.dependencia_id)) {
      return forbidden("No tiene permiso para ver esta comunicación");
    }

    return jsonResponse(await obtenerCorreoDeEvento(comunicacion, eventoId));
  } catch (err) {
    if (err instanceof SinCorreo) return notFound(err.message);
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}
