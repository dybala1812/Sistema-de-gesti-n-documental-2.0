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
      return forbidden("Solo Archivo Central puede responder comunicaciones");
    }

    const { id } = await params;
    const entradaId = Number(id);
    if (!Number.isFinite(entradaId)) return notFound();

    const body = await request.json();
    const asunto = String(body.asunto ?? "");
    const cuerpo = String(body.cuerpo ?? "");
    const messageIdEnviado = body.message_id_enviado ? String(body.message_id_enviado) : null;

    if (!asunto) return errorResponse("El asunto es obligatorio");

    const previa = await obtenerComunicacion(entradaId);
    if (!previa) return notFound("Comunicación no encontrada");
    if (previa.estado !== "respondida_dependencia") {
      return errorResponse(`No se puede responder una comunicación en estado "${previa.estado}"`);
    }

    const { data, error } = await supabase.rpc("fn_responder_remitente_usuario", {
      p_usuario_id: usuario.id,
      p_entrada_id: entradaId,
      p_asunto: asunto,
      p_cuerpo: cuerpo,
      p_message_id_enviado: messageIdEnviado,
    });

    if (error) {
      return errorResponse(error.message, 422, { codigo: error.code });
    }

    const entrada = await obtenerComunicacion(entradaId);
    return jsonResponse({ entrada, salida: data });
  } catch (err) {
    return handleError(err);
  }
}
