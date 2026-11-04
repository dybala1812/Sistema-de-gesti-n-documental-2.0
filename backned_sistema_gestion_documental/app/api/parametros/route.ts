/**
 * GET /api/parametros → parámetros del módulo con su tipo y rango (RF-AC-006).
 * Editar: PATCH /api/parametros/[clave] (solo quien tiene parametros.gestionar).
 */
import { NextRequest } from "next/server";
import { listarParametros } from "../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { handleError, jsonResponse } from "../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    await obtenerUsuarioAutenticado(request);
    return jsonResponse(await listarParametros());
  } catch (err) {
    return handleError(err);
  }
}
