/**
 * GET /api/archivo/buscar?anio=&mes=&dependencia_id=&tipo=&asunto_id=&asunto=&consecutivo=&persona=&trd=&texto=&alcance=&pagina=
 * Búsqueda avanzada en documentos clasificados y comunicaciones, 20 por página (RF-AC-014).
 * "consecutivo" acepta "385", "385 del 29 de febrero" o "ENT-2026-000041".
 */
import { NextRequest } from "next/server";
import { buscarArchivo } from "../../../../lib/archivo";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    return jsonResponse(await buscarArchivo(usuario.id, request.nextUrl.searchParams));
  } catch (err) {
    return handleError(err);
  }
}
