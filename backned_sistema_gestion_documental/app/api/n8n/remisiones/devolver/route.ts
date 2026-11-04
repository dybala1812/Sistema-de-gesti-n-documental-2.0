/**
 * POST /api/n8n/remisiones/devolver — #10 · F2
 * Registra la devolución a la dependencia (después de que n8n envió el correo). Da un nuevo plazo.
 *
 * Body: { usuario, comunicacion_id, dependencia_id?, message_id?, mensaje? }
 * Respuesta: { id, consecutivo, estado, dependencia_id, fecha_limite }
 */
import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { esServicioN8N } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { SolicitudInvalida, leer, parseBody } from "../../../../../lib/n8n";
import { handleError, jsonResponse, unauthorized, errorResponse } from "../../../../../lib/errors";

function sumarDiasHabiles(desde: Date, dias: number): Date {
  const fecha = new Date(desde);
  let restantes = dias;
  while (restantes > 0) {
    fecha.setDate(fecha.getDate() + 1);
    const dia = fecha.getDay();
    if (dia !== 0 && dia !== 6) restantes--;
  }
  return fecha;
}

export async function POST(request: NextRequest) {
  try {
    if (!esServicioN8N(request)) {
      return unauthorized("Token de servicio de n8n inválido");
    }

    const b = await parseBody(request);
    const comunicacionId = leer.entero(b, "comunicacion_id", true) as number;
    const dependenciaId = leer.entero(b, "dependencia_id");
    const usuarioId = leer.entero(b, "usuario", true) as number;
    const mensaje = leer.texto(b, "mensaje") ?? "";
    const messageId = leer.texto(b, "message_id");

    const previa = await obtenerComunicacion(comunicacionId);
    if (!previa) return errorResponse("Comunicación no encontrada", 404);
    if (previa.estado !== "remitida") {
      return errorResponse(`No se puede devolver una comunicación en estado "${previa.estado}"`, 409);
    }
    if (dependenciaId !== null && previa.dependencia_id !== dependenciaId) {
      return errorResponse("La comunicación no está remitida a la dependencia indicada", 409);
    }

    const { data: plazoParam } = await supabase.rpc("fn_parametro_entero", {
      p_clave: "plazo_respuesta_dias_habiles",
    });
    const plazo = plazoParam ? Number(plazoParam) : 5;
    const fechaLimite = sumarDiasHabiles(new Date(), plazo).toISOString().split("T")[0];

    const { error: updateError } = await supabase
      .from("comunicacion")
      .update({
        estado: "devuelta",
        fecha_limite: fechaLimite,
        n_recordatorios: 0,
        por_escalar: false,
        ultimo_recordatorio_en: null,
      })
      .eq("id", comunicacionId)
      .eq("estado", "remitida");

    if (updateError) {
      return errorResponse(updateError.message, 422, { codigo: updateError.code });
    }

    const { data: eventoDevolucion } = await supabase
      .from("comunicacion_evento")
      .select("id")
      .eq("comunicacion_id", comunicacionId)
      .eq("tipo", "devolucion")
      .order("id", { ascending: false })
      .limit(1)
      .single();

    if (eventoDevolucion) {
      const detalle: Record<string, unknown> = { plazo_dias_habiles: plazo };
      if (mensaje) detalle.mensaje = mensaje;
      if (usuarioId) detalle.usuario_id = usuarioId;
      await supabase
        .from("comunicacion_evento")
        .update({ message_id: messageId, detalle })
        .eq("id", eventoDevolucion.id);
    }

    const actualizada = await obtenerComunicacion(comunicacionId);
    return jsonResponse({
      id: actualizada!.id,
      consecutivo: actualizada!.consecutivo,
      estado: actualizada!.estado,
      dependencia_id: actualizada!.dependencia_id,
      fecha_limite: actualizada!.fecha_limite,
    });
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
