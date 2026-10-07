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
      return forbidden("Solo Archivo Central puede crear comunicaciones");
    }

    const { id } = await params;
    const correoId = Number(id);
    if (!Number.isFinite(correoId)) return notFound();

    const { data: correo, error: correoError } = await supabase
      .from("correo_sin_asociar")
      .select("*")
      .eq("id", correoId)
      .single();

    if (correoError || !correo) return notFound("Correo no encontrado");
    if (correo.resuelto) return errorResponse("El correo ya fue resuelto");

    const { data: creada, error } = await supabase.rpc("fn_registrar_correo_entrante_usuario", {
      p_usuario_id: usuario.id,
      p_message_id: correo.message_id,
      p_remitente_nombre: correo.de_nombre,
      p_remitente_correo: correo.de_correo,
      p_asunto: correo.asunto ?? "(sin asunto)",
      p_cuerpo: correo.cuerpo,
      p_recibido_en: correo.recibido_en,
      p_in_reply_to: correo.in_reply_to,
    });

    if (error) {
      return errorResponse(error.message, 422, { codigo: error.code });
    }

    const nuevaId = Array.isArray(creada) ? creada[0].id : creada.id;

    // Mover adjuntos
    if (correo.adjuntos && Array.isArray(correo.adjuntos)) {
      for (const archivoId of correo.adjuntos) {
        await supabase.from("comunicacion_adjunto").insert({
          comunicacion_id: nuevaId,
          archivo_id: archivoId,
        });
      }
    }

    // Evento de asociación manual
    await supabase.from("comunicacion_evento").insert({
      comunicacion_id: nuevaId,
      tipo: "asociacion_manual",
      usuario_id: usuario.id,
      detalle: { correo_id: correoId, accion: "creada_desde_correo_sin_asociar" },
    });

    // Marcar correo como resuelto
    await supabase
      .from("correo_sin_asociar")
      .update({
        resuelto: true,
        resuelto_como: "nueva",
        comunicacion_id: nuevaId,
        resuelto_por: usuario.id,
        resuelto_en: new Date().toISOString(),
      })
      .eq("id", correoId);

    const nueva = await obtenerComunicacion(nuevaId);
    return jsonResponse(nueva ?? creada);
  } catch (err) {
    return handleError(err);
  }
}
