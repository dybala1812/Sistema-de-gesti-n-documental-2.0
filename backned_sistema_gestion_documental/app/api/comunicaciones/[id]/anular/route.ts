import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { handleError, jsonResponse, notFound, forbidden, errorResponse } from "../../../../../lib/errors";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede anular comunicaciones");
    }

    const { id } = await params;
    const comunicacionId = Number(id);
    if (!Number.isFinite(comunicacionId)) return notFound();

    const body = await request.json();
    const motivo = String(body.motivo ?? "").trim();
    if (!motivo) return errorResponse("El motivo de anulación es obligatorio");

    const previa = await obtenerComunicacion(comunicacionId);
    if (!previa) return notFound("Comunicación no encontrada");
    if (["cerrada", "anulada"].includes(previa.estado)) {
      return errorResponse(`No se puede anular una comunicación "${previa.estado}"`);
    }

    const { data, error } = await supabase.rpc("fn_anular_comunicacion_usuario", {
      p_usuario_id: usuario.id,
      p_comunicacion_id: comunicacionId,
      p_motivo: motivo,
    });

    if (error) {
      return errorResponse(error.message, 422, { codigo: error.code });
    }

    const actualizada = await obtenerComunicacion(comunicacionId);
    return jsonResponse(actualizada ?? data);
  } catch (err) {
    return handleError(err);
  }
}
