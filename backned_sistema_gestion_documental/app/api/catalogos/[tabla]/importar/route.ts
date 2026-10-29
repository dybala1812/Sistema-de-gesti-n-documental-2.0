/**
 * POST /api/catalogos/[tabla]/importar  { filas: [...], confirmar: false|true }
 * Importa dependencias, TRD o programas desde las filas de un Excel (RF-AC-001, 002, 004).
 *  - confirmar=false: vista previa, valida cada fila contra la base sin escribir nada.
 *  - confirmar=true:  inserta las filas válidas y omite las que tienen error.
 * Respuesta: { confirmado, total, validas, con_error, filas: [{ fila, ok, id? | campo, tipo, error }] }.
 */
import { NextRequest } from "next/server";
import { obtenerConfig, importarCatalogo } from "../../../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { handleError, jsonResponse } from "../../../../../lib/errors";
import { parseBody } from "../../../../../lib/n8n";

export async function POST(request: NextRequest, { params }: { params: Promise<{ tabla: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const cfg = obtenerConfig((await params).tabla);
    const body = await parseBody(request);
    return jsonResponse(await importarCatalogo(usuario.id, cfg, body.filas, body.confirmar === true));
  } catch (err) {
    return handleError(err);
  }
}
