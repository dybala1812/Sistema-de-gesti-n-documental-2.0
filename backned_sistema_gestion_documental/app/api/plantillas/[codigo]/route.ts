/**
 * PATCH /api/plantillas/[codigo]  { asunto, cuerpo }  → guardar
 * PATCH /api/plantillas/[codigo]  { restablecer: true } → volver al texto original
 * Permiso plantillas.gestionar (Archivo Central y Administrador), auditado en la base.
 * El siguiente correo que envía F5 ya usa el texto nuevo (lo lee de plantilla_correo).
 */
import { NextRequest } from "next/server";
import { guardarPlantilla } from "../../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../lib/errors";
import { parseBody } from "../../../../lib/n8n";

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ codigo: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const { codigo } = await params;
    return jsonResponse(await guardarPlantilla(usuario.id, decodeURIComponent(codigo), await parseBody(request)));
  } catch (err) {
    return handleError(err);
  }
}
