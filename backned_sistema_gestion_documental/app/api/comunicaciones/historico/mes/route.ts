/**
 * GET /api/comunicaciones/historico/mes?anio=2024&mes=3&tipo=&pagina=1&limite=50
 * Comunicaciones de un mes del registro histórico (RF-AC-019), paginadas.
 */
import { NextRequest } from "next/server";
import { comunicacionesDelMes } from "../../../../../lib/historico";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    return jsonResponse(await comunicacionesDelMes(usuario.id, request.nextUrl.searchParams));
  } catch (err) {
    return handleError(err);
  }
}
