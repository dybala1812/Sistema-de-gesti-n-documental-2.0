/**
 * POST /api/n8n/dependencias/buscar
 * Busca una dependencia activa por su correo oficial.
 * Body: { correo: string }
 * Respuesta: { id, nombre, correo_oficial, estado } o { id: null }
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
    const correo = (leer.texto(b, "correo", true) as string).toLowerCase();

    const { data, error } = await supabase
      .from("dependencia")
      .select("id, nombre, correo_oficial, estado")
      .eq("estado", "activo")
      .or(`correo_oficial.ilike.${correo},correos_cc.ilike.*${correo}*`)
      .limit(1)
      .single();

    if (error || !data) {
      return jsonResponse({ id: null });
    }

    return jsonResponse({
      id: data.id,
      nombre: data.nombre,
      correo_oficial: data.correo_oficial,
      estado: data.estado,
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
