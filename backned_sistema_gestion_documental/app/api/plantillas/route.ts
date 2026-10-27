/**
 * GET /api/plantillas → plantillas de correo con su texto actual y el original (RF-AC-006).
 * Editar o restablecer: PATCH /api/plantillas/[codigo].
 */
import { NextRequest } from "next/server";
import { listarPlantillas } from "../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { handleError, jsonResponse } from "../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    await obtenerUsuarioAutenticado(request);
    return jsonResponse(await listarPlantillas());
  } catch (err) {
    return handleError(err);
  }
}
