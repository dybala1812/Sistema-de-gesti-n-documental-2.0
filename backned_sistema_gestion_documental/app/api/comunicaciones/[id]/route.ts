import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeVerDependencia } from "../../../../lib/auth";
import { obtenerComunicacion } from "../../../../lib/comunicaciones";
import { handleError, jsonResponse, notFound, forbidden } from "../../../../lib/errors";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const { id } = await params;
    const comunicacionId = Number(id);

    if (!Number.isFinite(comunicacionId)) {
      return notFound("Comunicación no válida");
    }

    const comunicacion = await obtenerComunicacion(comunicacionId);
    if (!comunicacion) {
      return notFound("Comunicación no encontrada");
    }

    if (!puedeVerDependencia(usuario, comunicacion.dependencia_id)) {
      return forbidden("No tiene permiso para ver esta comunicación");
    }

    return jsonResponse(comunicacion);
  } catch (err) {
    return handleError(err);
  }
}
