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
      return forbidden("Solo Archivo Central puede devolver comunicaciones");
    }

    const { id } = await params;
    const comunicacionId = Number(id);
    if (!Number.isFinite(comunicacionId)) return notFound();

    const body = await request.json();
    const mensaje = String(body.mensaje ?? "");
    const messageIdEnviado = body.message_id_enviado ? String(body.message_id_enviado) : null;

    const previa = await obtenerComunicacion(comunicacionId);
    if (!previa) return notFound("Comunicación no encontrada");
    if (previa.estado !== "respondida_dependencia") {
      return errorResponse(`No se puede devolver una comunicación en estado "${previa.estado}"`);
    }

    const { data, error } = await supabase.rpc("fn_devolver_respuesta_usuario", {
      p_usuario_id: usuario.id,
      p_comunicacion_id: comunicacionId,
      p_mensaje: mensaje,
      p_message_id_enviado: messageIdEnviado,
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
