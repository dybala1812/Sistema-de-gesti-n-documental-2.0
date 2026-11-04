/**
 * POST /api/n8n/comunicaciones — registra una comunicación entrante (flujo F1 de n8n · RF-AC-015).
 *
 * Autenticación: Authorization: Bearer <N8N_SERVICE_TOKEN> (token de servicio, no usuario de NOVA).
 * Los adjuntos se suben antes con POST /api/archivos y aquí se envían sus `archivo_id`.
 *
 * Idempotente por Message-ID: si el correo ya estaba registrado responde 200 con la
 * misma comunicación (creada: false) en lugar de duplicarla. n8n solo debe marcar el
 * correo como leído cuando reciba 200 o 201.
 */
import { NextRequest } from "next/server";
import { esServicioN8N } from "../../../../lib/auth";
import { supabase, assertSupabaseConfig } from "../../../../lib/supabase";
import { SolicitudInvalida, leer, parseBody } from "../../../../lib/n8n";
import { errorResponse, handleError, jsonResponse, unauthorized } from "../../../../lib/errors";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CORREO = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const MAX_CUERPO = 100_000;

export async function POST(request: NextRequest) {
  try {
    if (!esServicioN8N(request)) {
      return unauthorized("Token de servicio de n8n inválido");
    }

    const b = await parseBody(request);

    // ── Validación ─────────────────────────────────────────────────────────
    const messageId = leer.texto(b, "message_id", true);
    const remitenteCorreo = leer.texto(b, "remitente_correo", true);
    if (remitenteCorreo && !CORREO.test(remitenteCorreo)) {
      throw new SolicitudInvalida("remitente_correo debe ser un correo válido", "remitente_correo", "formato");
    }
    const recibidoEn = leer.fecha(b, "recibido_en") ?? new Date().toISOString();
    const adjuntos = leer.uuids(b, "adjuntos");
    const cuerpo = leer.texto(b, "cuerpo");
    if (cuerpo && cuerpo.length > MAX_CUERPO) {
      throw new SolicitudInvalida(`cuerpo supera ${MAX_CUERPO} caracteres`, "cuerpo", "rango");
    }

    assertSupabaseConfig();

    // ── Registro (una transacción en la BD: comunicación + adjuntos) ───────
    const { data, error } = await supabase.rpc("fn_registrar_comunicacion_n8n", {
      p_message_id: messageId,
      p_remitente_nombre: leer.texto(b, "remitente_nombre"),
      p_remitente_correo: remitenteCorreo,
      p_asunto: leer.texto(b, "asunto") ?? "(sin asunto)",
      p_cuerpo: cuerpo,
      p_recibido_en: recibidoEn,
      p_in_reply_to: leer.texto(b, "in_reply_to"),
      p_adjuntos: adjuntos,
    });

    if (error) {
      // 23503 = adjunto inexistente; 22023 = dato inválido (lanzados por la función).
      if (error.code === "23503") return errorResponse("Algún adjunto no existe", 400, { detalle: error.message, codigo: error.code });
      if (error.code === "22023") return errorResponse(error.message, 400, { codigo: error.code });
      throw new Error(error.message);
    }

    const fila = (Array.isArray(data) ? data[0] : data) as {
      comunicacion_id: number;
      consecutivo: string;
      estado: string;
      creada: boolean;
      adjuntos: number;
    };

    return jsonResponse(
      {
        comunicacion_id: fila.comunicacion_id,
        consecutivo: fila.consecutivo,
        estado: fila.estado,
        creada: fila.creada,
        adjuntos: fila.adjuntos,
      },
      fila.creada ? 201 : 200,
    );
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
