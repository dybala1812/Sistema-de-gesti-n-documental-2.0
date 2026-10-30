/**
 * GET /api/historias/[id]/documentos
 * Documentos de una historia académica (título, fecha, archivo) para la ficha del estudiante (RF-AC-020).
 * Requiere historias.consultar y que el perfil pueda ver esa historia (RN-AC-06). Función SQL: fn_historia_documentos (migración 28).
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { rpc } from "../../../../../lib/catalogos";
import { SolicitudInvalida, idRuta } from "../../../../../lib/n8n";
import { errorResponse, handleError, jsonResponse } from "../../../../../lib/errors";

const MIGRACION = "20261028000000_historias_transferencias_busqueda.sql";

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const historiaId = idRuta(await params);
    return jsonResponse(await rpc("fn_historia_documentos", { p_usuario_id: usuario.id, p_historia_id: historiaId }, MIGRACION));
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}
