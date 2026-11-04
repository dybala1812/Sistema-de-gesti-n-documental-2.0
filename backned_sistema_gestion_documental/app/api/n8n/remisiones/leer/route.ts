/**
 * POST /api/n8n/remisiones/leer — #8 · F2
 * Lee la comunicación y la dependencia para remitir o devolver.
 * Incluye datos del remitente original para que n8n pueda ponerlos en el correo.
 *
 * Body: { comunicacion_id, dependencia_id? }
 * Respuesta: { id, tipo, estado, consecutivo, asunto, cuerpo, remitente_nombre, remitente_correo,
 *              dep_id, dependencia, dep_estado, correo_oficial, plazo_defecto, adjuntos[] }
 *              o { id: null } si no existe.
 */
import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { esServicioN8N } from "../../../../../lib/auth";
import { SolicitudInvalida, leer, parseBody } from "../../../../../lib/n8n";
import { handleError, jsonResponse, unauthorized, errorResponse } from "../../../../../lib/errors";

export async function POST(request: NextRequest) {
  try {
    if (!esServicioN8N(request)) {
      return unauthorized("Token de servicio de n8n inválido");
    }

    const b = await parseBody(request);
    const comunicacionId = leer.entero(b, "comunicacion_id", true) as number;
    const dependenciaId = leer.entero(b, "dependencia_id");

    const { data: com, error: comError } = await supabase
      .from("comunicacion")
      .select("id, tipo, estado, consecutivo, asunto, cuerpo, remitente_nombre, remitente_correo, dependencia_id")
      .eq("id", comunicacionId)
      .single();

    if (comError || !com) {
      return jsonResponse({ id: null });
    }

    const depId = dependenciaId ?? com.dependencia_id;
    let dependencia: { id: number; nombre: string; estado: string; correo_oficial: string } | null = null;
    if (depId) {
      const { data: depData } = await supabase
        .from("dependencia")
        .select("id, nombre, estado, correo_oficial")
        .eq("id", depId)
        .single();
      dependencia = depData;
    }

    const { data: plazoParam } = await supabase.rpc("fn_parametro_entero", {
      p_clave: "plazo_respuesta_dias_habiles",
    });

    const { data: adjuntos } = await supabase
      .from("comunicacion_adjunto")
      .select("archivo_id")
      .eq("comunicacion_id", comunicacionId)
      .order("id");

    return jsonResponse({
      id: com.id,
      tipo: com.tipo,
      estado: com.estado,
      consecutivo: com.consecutivo,
      asunto: com.asunto,
      cuerpo: com.cuerpo,
      remitente_nombre: com.remitente_nombre,
      remitente_correo: com.remitente_correo,
      dep_id: dependencia?.id ?? null,
      dependencia: dependencia?.nombre ?? null,
      dep_estado: dependencia?.estado ?? null,
      correo_oficial: dependencia?.correo_oficial ?? null,
      plazo_defecto: plazoParam ? Number(plazoParam) : 5,
      adjuntos: (adjuntos ?? []).map((a) => a.archivo_id),
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
