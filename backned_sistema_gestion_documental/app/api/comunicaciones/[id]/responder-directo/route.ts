/**
 * POST /api/comunicaciones/[id]/responder-directo
 * Permite responder directamente al remitente sin pasar por una dependencia.
 *
 * Excepción documentada a RN-AC-09: una entrada en estado "nueva" puede pasar a
 * "respondida_dependencia" y cerrarse con F3 cuando Archivo Central responde al remitente.
 *
 * El backend:
 *  1. Actualiza la comunicación a "respondida_dependencia" y registra un evento
 *     "respuesta_dependencia" marcado como directo.
 *  2. Dispara el webhook de n8n F3 para que envíe el correo y cierre la entrada.
 */
import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { dispararWebhookN8N } from "../../../../../lib/n8nWebhook";
import { SolicitudInvalida, idRuta, leer, parseBody } from "../../../../../lib/n8n";
import { errorResponse, forbidden, handleError, jsonResponse, notFound } from "../../../../../lib/errors";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede responder comunicaciones");
    }

    const comunicacionId = idRuta(await params);
    const com = await obtenerComunicacion(comunicacionId);
    if (!com) return notFound("Comunicación no encontrada");

    if (com.tipo !== "ENT") {
      return errorResponse("Solo se responden comunicaciones de entrada", 409);
    }
    if (com.estado === "cerrada" || com.estado === "anulada") {
      return errorResponse(`No se puede responder una comunicación "${com.estado}"`, 409);
    }

    const b = await parseBody(request);
    const asunto = leer.texto(b, "asunto");
    const cuerpo = leer.texto(b, "cuerpo", true);
    const adjuntos = leer.uuids(b, "adjuntos");

    // Prepara la comunicación para que F3 la acepte.
    const { error: rpcError } = await supabase.rpc("fn_responder_directo", {
      p_usuario_id: usuario.id,
      p_comunicacion_id: comunicacionId,
      p_mensaje: cuerpo,
    });
    if (rpcError) {
      return errorResponse(rpcError.message, 400, { codigo: rpcError.code });
    }

    const url = process.env.N8N_WEBHOOK_RESPONDER_URL;
    const resultado = await dispararWebhookN8N(url, {
      comunicacion_id: comunicacionId,
      usuario_id: usuario.id,
      asunto,
      cuerpo,
      destinatario: com.remitente_correo,
      archivo_ids: adjuntos,
    });

    return jsonResponse({ ok: true, comunicacion_id: comunicacionId, n8n: resultado });
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
