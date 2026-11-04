/**
 * POST /api/comunicaciones/[id]/enviar-respuesta
 * Body: { asunto?, cuerpo, adjuntos? }
 * Envía al remitente la respuesta de una comunicación respondida por la dependencia: el backend
 * revisa el permiso del usuario y dispara el webhook de n8n F3 (N8N_WEBHOOK_RESPONDER_URL) con su id;
 * n8n envía el correo y luego cierra la entrada. Antes lo hacía el navegador con el token de n8n.
 * Para responder sin pasar por la dependencia está /responder-directo.
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { dispararWebhookN8N } from "../../../../../lib/n8nWebhook";
import { idRuta, leer, parseBody } from "../../../../../lib/n8n";
import { errorFormulario, forbidden, handleError, jsonResponse, notFound } from "../../../../../lib/errors";

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
    if (com.estado !== "respondida_dependencia") {
      return errorFormulario(`Solo se envía la respuesta de una comunicación respondida por la dependencia (estado actual: "${com.estado}")`, 409);
    }

    const b = await parseBody(request);
    const asunto = leer.texto(b, "asunto");
    const cuerpo = leer.texto(b, "cuerpo", true);
    const adjuntos = leer.uuids(b, "adjuntos");

    await dispararWebhookN8N(process.env.N8N_WEBHOOK_RESPONDER_URL, {
      modo: "responder",
      comunicacion_id: comunicacionId,
      usuario_id: usuario.id,
      asunto,
      cuerpo,
      adjuntos_ids: adjuntos,
    });

    return jsonResponse(await obtenerComunicacion(comunicacionId));
  } catch (err) {
    return handleError(err);
  }
}
