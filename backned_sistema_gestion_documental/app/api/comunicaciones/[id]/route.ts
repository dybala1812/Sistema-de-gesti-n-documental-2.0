import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeVerDependencia } from "../../../../lib/auth";
import { obtenerComunicacion } from "../../../../lib/comunicaciones";
import { SolicitudInvalida, idRuta } from "../../../../lib/n8n";
import { errorResponse, handleError, jsonResponse, notFound, forbidden } from "../../../../lib/errors";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const comunicacionId = idRuta(await params);

    const comunicacion = await obtenerComunicacion(comunicacionId);
    if (!comunicacion) {
      return notFound("Comunicación no encontrada");
    }

    if (!puedeVerDependencia(usuario, comunicacion.dependencia_id)) {
      return forbidden("No tiene permiso para ver esta comunicación");
    }

    return jsonResponse(comunicacion);
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, {
        detalle: err.message,
        campo: err.campo,
        tipo: err.tipo,
      });
    }
    return handleError(err);
  }
}
