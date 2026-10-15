import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase"; // AJUSTA

export async function GET() {
  try {
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
    console.error("GET /api/transferencias/resumen", e);
    return NextResponse.json({ mensaje: "No se pudo calcular el resumen" }, { status: 500 });
  }
}