/**
 * GET /api/archivo/arbol
 * Árbol Dependencia → Año → Asunto con la cantidad de documentos clasificados (RF-AC-013).
 * Requiere documentos.consultar; un usuario de Dependencia solo recibe su dependencia.
 */
import { NextRequest } from "next/server";
import { arbolArchivo } from "../../../../lib/archivo";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    return jsonResponse(await arbolArchivo(usuario.id));
  } catch (err) {
    return handleError(err);
  }
}
