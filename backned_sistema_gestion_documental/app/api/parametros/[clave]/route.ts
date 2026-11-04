/**
 * PATCH /api/parametros/[clave]  { valor }
 * Cambia un parámetro; la base valida tipo y rango, revisa el permiso parametros.gestionar
 * y deja el cambio (o el intento denegado) en la auditoría. Función SQL: fn_parametro_guardar.
 */
import { NextRequest } from "next/server";
import { guardarParametro } from "../../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../lib/errors";
import { parseBody } from "../../../../lib/n8n";

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ clave: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const { clave } = await params;
    const body = await parseBody(request);
    return jsonResponse(await guardarParametro(usuario.id, decodeURIComponent(clave), body.valor));
  } catch (err) {
    return handleError(err);
  }
}
