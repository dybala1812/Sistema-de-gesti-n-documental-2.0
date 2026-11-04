/**
 * POST /api/comunicaciones/[id]/recordatorio-manual
 * Dispara manualmente un recordatorio para una comunicación remitida/devuelta.
 * El backend llama al webhook de n8n F4 (modo recordatorio); n8n envía el correo y luego
 * registra el recordatorio vía /api/n8n/recordatorios/registrar.
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
      return forbidden("Solo Archivo Central puede enviar recordatorios");
    }

    const comunicacionId = idRuta(await params);
    const com = await obtenerComunicacion(comunicacionId);
    if (!com) return notFound("Comunicación no encontrada");

    if (com.estado !== "remitida" && com.estado !== "devuelta") {
      return errorResponse(`No se puede recordar una comunicación en estado "${com.estado}"`, 409);
    }

    const { data: dep } = await supabase
      .from("dependencia")
      .select("id, nombre, correo_oficial")
      .eq("id", com.dependencia_id)
      .single();

    const b = await parseBody(request);
    const asunto = leer.texto(b, "asunto");
    const cuerpo = leer.texto(b, "cuerpo");
    const adjuntos = leer.uuids(b, "adjuntos");

    const url = process.env.N8N_WEBHOOK_RECORDATORIO_URL;
    const resultado = await dispararWebhookN8N(url, {
      modo: "recordatorio",
      comunicacion_id: comunicacionId,
      usuario_id: usuario.id,
      destinatario_correo: dep?.correo_oficial,
      destinatario_nombre: dep?.nombre,
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
