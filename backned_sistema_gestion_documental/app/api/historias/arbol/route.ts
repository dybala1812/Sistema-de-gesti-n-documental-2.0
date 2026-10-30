/**
 * GET /api/historias/arbol
 * Árbol de historias académicas Estado → Año → Nivel → Programa con cuántas hay en cada nodo (RF-AC-020).
 * Requiere historias.consultar; Registro Académico solo ve las activas (RN-AC-06). Función SQL: fn_historias_arbol (migración 28).
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { rpc } from "../../../../lib/catalogos";
import { handleError, jsonResponse } from "../../../../lib/errors";

const MIGRACION = "20261028000000_historias_transferencias_busqueda.sql";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    return jsonResponse(await rpc("fn_historias_arbol", { p_usuario_id: usuario.id }, MIGRACION));
  } catch (err) {
    return handleError(err);
  }
}
