import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { errorSistema } from "@/lib/errors";
import { obtenerUsuarioAutenticado } from "@/lib/auth";

export async function GET(req: Request) {
  try {
    // Como el resto de rutas: solo usuarios autenticados (antes respondía a cualquiera).
    await obtenerUsuarioAutenticado(req);
    const anioActual = new Date().getFullYear();
    const anioMaximo = anioActual - 2; // TODO: leerlo de la tabla `parametro` si ya guardan ahí la regla de los dos años

    const { data: deps, error: e1 } = await supabase
      .from("dependencia").select("id, nombre").eq("estado", "activo").order("nombre");
    if (e1) throw e1;

    const { data: ent, error: e2 } = await supabase
      .from("transferencia").select("dependencia_id")
      .eq("anio", anioMaximo).is("anulado_en", null);
    if (e2) throw e2;

    const yaEntregaron = new Set((ent ?? []).map(t => t.dependencia_id));
    const todas = (deps ?? []).map(d => d.nombre as string);

    return NextResponse.json({
      anioActual, anioMaximo,
      proximoAnio: anioActual + 1, proximoMaximo: anioMaximo + 1,
      total: todas.length,
      faltan: (deps ?? []).filter(d => !yaEntregaron.has(d.id)).map(d => d.nombre as string),
      dependencias: todas, // para el selector del asistente "Nueva transferencia"
    });
  } catch (e) {
    if (e instanceof Response) return e; // 401 sin token o token inválido
    console.error("GET /api/transferencias/resumen", e);
    return errorSistema("INTERNO", 500, { detalle: "no se pudo calcular el resumen" });
  }
}