import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../lib/auth";
import { listarCorreosSinAsociar } from "../../../lib/comunicaciones";
import { handleError, jsonResponse, forbidden } from "../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede ver correos sin asociar");
    }

    const correos = await listarCorreosSinAsociar();
    return jsonResponse(correos);
  } catch (err) {
    return handleError(err);
  }
}
