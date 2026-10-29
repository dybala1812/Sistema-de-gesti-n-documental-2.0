/**
 * POST /api/comunicaciones/historico/importar
 * Body: { filas: [{ tipo?, numero_original, fecha (AAAA-MM-DD), asunto, remitente?, destinatario?,
 *         dependencia? (código o nombre), observaciones? }], tipo?: tipo para todas las filas, confirmar?: boolean }
 * Sin confirmar devuelve la vista previa por fila (nueva, ya_importada, revisar, error) sin guardar.
 * Requiere cargas.historico. Idempotente: reimportar el mismo Excel no duplica (RF-AC-019).
 */
import { NextRequest } from "next/server";
import { importarHistorico } from "../../../../../lib/historico";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { errorFormulario, handleError, jsonResponse } from "../../../../../lib/errors";

export async function POST(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const cuerpo = await request.json().catch(() => null);
    if (!cuerpo || typeof cuerpo !== "object") return errorFormulario("Cuerpo de la petición no válido", 400);
    return jsonResponse(await importarHistorico(usuario.id, cuerpo as Record<string, unknown>));
  } catch (err) {
    return handleError(err);
  }
}
