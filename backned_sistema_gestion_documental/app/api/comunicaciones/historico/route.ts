/**
 * GET /api/comunicaciones/historico?anio=2024&tipo=recibidas|enviadas|internas
 * Calendario del registro histórico (RF-AC-019): por mes, total, cerradas en el sistema e importadas.
 * Requiere comunicaciones.consultar; un usuario de Dependencia solo cuenta las de su dependencia.
 */
import { NextRequest } from "next/server";
import { calendarioHistorico } from "../../../../lib/historico";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    return jsonResponse(await calendarioHistorico(usuario.id, request.nextUrl.searchParams));
  } catch (err) {
    return handleError(err);
  }
}
