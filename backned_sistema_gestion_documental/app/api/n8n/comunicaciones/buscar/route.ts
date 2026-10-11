/**
 * POST /api/n8n/comunicaciones/buscar
 * Busca comunicaciones por message_id, remitente, consecutivo o asunto.
 * Body: { message_id?, remitente_correo?, consecutivo?, asunto?, limite? }
 * Respuesta: array de comunicaciones con datos básicos.
 */
import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { esServicioN8N } from "../../../../../lib/auth";
import { SolicitudInvalida, parseBody } from "../../../../../lib/n8n";
import { handleError, jsonResponse, unauthorized, errorResponse } from "../../../../../lib/errors";

export async function POST(request: NextRequest) {
  try {
    if (!esServicioN8N(request)) {
      return unauthorized("Token de servicio de n8n inválido");
    }

    const b = await parseBody(request);

    const rawLimite = b.limite;
    let limite = 5;
    if (rawLimite !== undefined && rawLimite !== null && rawLimite !== "") {
      const n = Number(rawLimite);
      if (!Number.isInteger(n) || n <= 0 || n > 20) {
        throw new SolicitudInvalida("limite debe ser un entero entre 1 y 20", "limite", "rango");
      }
      limite = n;
    }

    let query = supabase
      .from("comunicacion")
      .select("id, tipo, estado, consecutivo, asunto, remitente_nombre, remitente_correo, dependencia_id, fecha_recepcion")
      .limit(limite);

    if (typeof b.message_id === "string" && b.message_id.trim() !== "") {
      query = query.eq("message_id", b.message_id.trim());
    }

    if (typeof b.consecutivo === "string" && b.consecutivo.trim() !== "") {
      query = query.ilike("consecutivo", `%${b.consecutivo.trim()}%`);
    }

    if (typeof b.remitente_correo === "string" && b.remitente_correo.trim() !== "") {
      query = query.ilike("remitente_correo", `%${b.remitente_correo.trim().toLowerCase()}%`);
    }

    if (typeof b.asunto === "string" && b.asunto.trim() !== "") {
      query = query.ilike("asunto", `%${b.asunto.trim()}%`);
    }

    const { data, error } = await query.order("fecha_recepcion", { ascending: false });

    if (error) {
      return errorResponse(error.message, 500, { codigo: error.code });
    }

    return jsonResponse(data ?? []);
  } catch (err) {
    return handleError(err);
  }
}
