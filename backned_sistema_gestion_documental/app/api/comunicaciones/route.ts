import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../lib/auth";
import { listarComunicaciones } from "../../../lib/comunicaciones";
import { SolicitudInvalida } from "../../../lib/n8n";
import { errorResponse, handleError, jsonResponse, forbidden } from "../../../lib/errors";

function enteroQuery(searchParams: URLSearchParams, campo: string): number | undefined {
  const raw = searchParams.get(campo);
  if (raw === null || raw === "") return undefined;
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) {
    throw new SolicitudInvalida(`${campo} debe ser un entero positivo`, campo, "rango");
  }
  return n;
}

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const { searchParams } = request.nextUrl;

    const filtros = {
      estado: searchParams.get("estado") ?? undefined,
      anio: enteroQuery(searchParams, "anio"),
      mes: enteroQuery(searchParams, "mes"),
      dependencia_id: enteroQuery(searchParams, "dependencia_id"),
      tipo: searchParams.get("tipo") ?? undefined,
      q: searchParams.get("q") ?? undefined,
    };

    const comunicaciones = await listarComunicaciones(usuario, filtros);
    return jsonResponse(comunicaciones);
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
