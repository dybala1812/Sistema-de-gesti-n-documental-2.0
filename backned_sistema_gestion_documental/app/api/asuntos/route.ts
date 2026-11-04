/**
 * GET /api/asuntos?dependencia_id=  → asuntos activos de una dependencia, con su código TRD.
 * Va en: app/api/asuntos/route.ts
 */
import { NextRequest } from "next/server";

import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { supabase } from "../../../lib/supabase"; // AJUSTA si tu cliente se exporta con otro nombre
import { SolicitudInvalida } from "../../../lib/n8n";
import { errorResponse, handleError, jsonResponse } from "../../../lib/errors";

interface Fila { id: number; nombre: string; trd: { codigo: string } | { codigo: string }[] | null }

export async function GET(request: NextRequest) {
  try {
    await obtenerUsuarioAutenticado(request);
    const raw = request.nextUrl.searchParams.get("dependencia_id");
    const dependenciaId = Number(raw);
    if (!raw || !Number.isInteger(dependenciaId) || dependenciaId <= 0) {
      throw new SolicitudInvalida("dependencia_id debe ser un entero positivo", "dependencia_id", "rango");
    }
    const { data, error } = await supabase
      .from("asunto")
      .select("id, nombre, trd:trd_id ( codigo )")
      .eq("dependencia_id", dependenciaId)
      .eq("estado", "activo")
      .order("nombre");
    if (error) throw error;
    return jsonResponse(
      ((data ?? []) as unknown as Fila[]).map(a => {
        const trd = Array.isArray(a.trd) ? a.trd[0] : a.trd;
        return { id: a.id, nombre: a.nombre, trd_codigo: trd?.codigo ?? null };
      }),
    );
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}