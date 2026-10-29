/**
 * POST /api/comunicaciones/[id]/enviar-remision
 * Body: { dependencia_id, plazo_dias_habiles?, mensaje?, adjuntos? }
 * Remite una comunicación nueva a una dependencia por correo: el backend revisa el permiso del usuario
 * y dispara el webhook de n8n F2 (N8N_WEBHOOK_REMITIR_URL) con su id; n8n envía el correo y luego
 * actualiza el estado vía /api/n8n/remisiones/remitir. Antes lo hacía el navegador con el token de
 * n8n, que quedaba expuesto en el JavaScript.
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
      return forbidden("Solo Archivo Central puede remitir comunicaciones");
    }

    const comunicacionId = idRuta(await params);
    const com = await obtenerComunicacion(comunicacionId);
    if (!com) return notFound("Comunicación no encontrada");
    if (com.estado !== "nueva") {
      return errorFormulario(`No se puede remitir una comunicación en estado "${com.estado}"`, 409);
    }

    const b = await parseBody(request);
    const dependenciaId = leer.entero(b, "dependencia_id", true) as number;
    const plazo = leer.entero(b, "plazo_dias_habiles");
    const mensaje = leer.texto(b, "mensaje") ?? "";
    const adjuntos = leer.uuids(b, "adjuntos");

    await dispararWebhookN8N(process.env.N8N_WEBHOOK_REMITIR_URL, {
      modo: "remitir",
      comunicacion_id: comunicacionId,
      usuario_id: usuario.id,
      dependencia_id: dependenciaId,
      plazo_dias_habiles: plazo,
      mensaje,
      adjuntos_ids: adjuntos,
    });

    // n8n ya actualizó el estado: se devuelve la comunicación al día.
    return jsonResponse(await obtenerComunicacion(comunicacionId));
  } catch (err) {
    return handleError(err);
  }
}
