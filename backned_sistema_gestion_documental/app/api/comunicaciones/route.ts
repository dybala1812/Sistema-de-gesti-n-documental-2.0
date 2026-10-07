import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../lib/auth";
import { listarComunicaciones } from "../../../lib/comunicaciones";
import { errorResponse, handleError, jsonResponse, forbidden } from "../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const { searchParams } = request.nextUrl;

    const filtros = {
      estado: searchParams.get("estado") ?? undefined,
      anio: searchParams.get("anio") ? Number(searchParams.get("anio")) : undefined,
      mes: searchParams.get("mes") ? Number(searchParams.get("mes")) : undefined,
      dependencia_id: searchParams.get("dependencia_id") ? Number(searchParams.get("dependencia_id")) : undefined,
      tipo: searchParams.get("tipo") ?? undefined,
      q: searchParams.get("q") ?? undefined,
    };

    const comunicaciones = await listarComunicaciones(usuario, filtros);
    return jsonResponse(comunicaciones);
  } catch (err) {
    return handleError(err);
  }
}

export async function POST(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede crear comunicaciones manuales");
    }

    // TODO: crear comunicación manual (RF-AC-015 origen manual). Por ahora no implementado.
    return errorResponse("Creación manual pendiente de implementar", 501);
  } catch (err) {
    return handleError(err);
  }
}
