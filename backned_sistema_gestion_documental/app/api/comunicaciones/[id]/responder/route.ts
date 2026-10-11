import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { SolicitudInvalida, leer, parseBody, idRuta } from "../../../../../lib/n8n";
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

    const entradaId = idRuta(await params);
    const b = await parseBody(request);
    const asunto = leer.texto(b, "asunto", true) as string;
    const cuerpo = leer.texto(b, "cuerpo", true) as string;
    const messageIdEnviado = leer.texto(b, "message_id_enviado");

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
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, {
        detalle: err.message,
        campo: err.campo,
        tipo: err.tipo,
      });
    }
    return handleError(err);
  }
}
