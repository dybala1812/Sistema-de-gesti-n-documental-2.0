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
      return forbidden("Solo Archivo Central puede asociar correos");
    }

    const { id } = await params;
    const correoId = Number(id);
    if (!Number.isFinite(correoId)) return notFound();

    const body = await request.json();
    const comunicacionId = Number(body.comunicacion_id);
    if (!Number.isFinite(comunicacionId)) {
      return errorResponse("comunicacion_id es obligatorio");
    }

    const comunicacion = await obtenerComunicacion(comunicacionId);
    if (!comunicacion) return notFound("Comunicación no encontrada");
    if (!["remitida", "devuelta"].includes(comunicacion.estado)) {
      return errorResponse(`No se puede asociar una respuesta a una comunicación "${comunicacion.estado}"`);
    }

    const { data: correo, error: correoError } = await supabase
      .from("correo_sin_asociar")
      .select("*")
      .eq("id", correoId)
      .single();

    if (correoError || !correo) return notFound("Correo no encontrado");
    if (correo.resuelto) return errorResponse("El correo ya fue resuelto");

    // Actualizar estado de la comunicación a respondida_dependencia
    const { error: updError } = await supabase
      .from("comunicacion")
      .update({ estado: "respondida_dependencia" })
      .eq("id", comunicacionId);

    if (updError) {
      return errorResponse(updError.message, 422, { codigo: updError.code });
    }

    // Insertar eventos
    await supabase.from("comunicacion_evento").insert({
      comunicacion_id: comunicacionId,
      tipo: "asociacion_manual",
      usuario_id: usuario.id,
      detalle: { correo_id: correoId, de_correo: correo.de_correo },
    });

    await supabase.from("comunicacion_evento").insert({
      comunicacion_id: comunicacionId,
      tipo: "respuesta_dependencia",
      estado_anterior: comunicacion.estado,
      estado_nuevo: "respondida_dependencia",
      usuario_id: usuario.id,
      detalle: { asunto: correo.asunto },
    });

    // Mover adjuntos del correo a la comunicación
    if (correo.adjuntos && Array.isArray(correo.adjuntos)) {
      for (const archivoId of correo.adjuntos) {
        await supabase.from("comunicacion_adjunto").insert({
          comunicacion_id: comunicacionId,
          archivo_id: archivoId,
        });
      }
    }

    // Marcar correo como resuelto
    await supabase
      .from("correo_sin_asociar")
      .update({
        resuelto: true,
        resuelto_como: "asociado",
        comunicacion_id: comunicacionId,
        resuelto_por: usuario.id,
        resuelto_en: new Date().toISOString(),
      })
      .eq("id", correoId);

    const actualizada = await obtenerComunicacion(comunicacionId);
    return jsonResponse(actualizada);
  } catch (err) {
    return handleError(err);
  }
}
