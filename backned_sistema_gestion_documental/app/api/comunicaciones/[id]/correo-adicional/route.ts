/**
 * POST /api/comunicaciones/[id]/correo-adicional
 * Envía un correo adicional asociado a una comunicación (a remitente o dependencia).
 * El backend llama al webhook de n8n F4 (modo adicional); n8n envía el correo y luego
 * registra el evento vía /api/n8n/correos/adicional.
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
      return forbidden("Solo Archivo Central puede enviar correos adicionales");
    }

    const comunicacionId = idRuta(await params);
    const com = await obtenerComunicacion(comunicacionId);
    if (!com) return notFound("Comunicación no encontrada");

    if (com.estado === "cerrada" || com.estado === "anulada") {
      return errorResponse(`No se puede enviar un correo adicional a una comunicación "${com.estado}"`, 409);
    }

    const { data: dep } = await supabase
      .from("dependencia")
      .select("id, nombre, correo_oficial")
      .eq("id", com.dependencia_id)
      .single();

    const b = await parseBody(request);
    const destinatarioTipo = leer.texto(b, "destinatario_tipo", true);
    if (destinatarioTipo !== "remitente" && destinatarioTipo !== "dependencia") {
      throw new SolicitudInvalida("destinatario_tipo debe ser 'remitente' o 'dependencia'", "destinatario_tipo", "formato");
    }
    const asunto = leer.texto(b, "asunto", true);
    const cuerpo = leer.texto(b, "cuerpo", true);
    const adjuntos = leer.uuids(b, "adjuntos");

    const destinatarioCorreo = destinatarioTipo === "remitente" ? com.remitente_correo : dep?.correo_oficial;
    const destinatarioNombre = destinatarioTipo === "remitente" ? com.remitente_nombre : dep?.nombre;

    const url = process.env.N8N_WEBHOOK_RECORDATORIO_URL;
    const resultado = await dispararWebhookN8N(url, {
      modo: "adicional",
      comunicacion_id: comunicacionId,
      usuario_id: usuario.id,
      destinatario_tipo: destinatarioTipo,
      destinatario_correo: destinatarioCorreo,
      destinatario_nombre: destinatarioNombre,
      consecutivo: com.consecutivo,
      asunto,
      cuerpo,
      adjuntos_ids: adjuntos,
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
