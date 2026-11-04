import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { SolicitudInvalida, leer, parseBody, idRuta } from "../../../../../lib/n8n";
import { handleError, jsonResponse, notFound, forbidden, errorResponse } from "../../../../../lib/errors";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede anular comunicaciones");
    }

    const comunicacionId = idRuta(await params);
    const b = await parseBody(request);
    const motivo = leer.texto(b, "motivo", true) as string;

    const previa = await obtenerComunicacion(comunicacionId);
    if (!previa) return notFound("Comunicación no encontrada");
    if (["cerrada", "anulada"].includes(previa.estado)) {
      return errorResponse(`No se puede anular una comunicación "${previa.estado}"`);
    }

    const { data, error } = await supabase.rpc("fn_anular_comunicacion_usuario", {
      p_usuario_id: usuario.id,
      p_comunicacion_id: comunicacionId,
      p_motivo: motivo,
    });

    if (error) {
      return errorResponse(error.message, 422, { codigo: error.code });
    }

    const actualizada = await obtenerComunicacion(comunicacionId);
    return jsonResponse(actualizada ?? data);
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
