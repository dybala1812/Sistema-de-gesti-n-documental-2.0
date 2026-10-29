import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase"; // AJUSTA: nombre/ruta real de tu cliente de Supabase
import { errorFormulario, errorSistema } from "@/lib/errors";
// import { requireUser } from "@/lib/auth"; // AJUSTA

// Next 15: params es una promesa. Si tienes Next 14, usa ctx: { params: { id: string } } y quita el await.
type Ctx = { params: Promise<{ id: string }> };

const mapTipo = (s: string): "fisica" | "digital" | "ambas" => {
  const t = s.toLowerCase();
  if (/mixt|ambas/.test(t) || (t.includes("fis") && t.includes("dig"))) return "ambas";
  return t.includes("dig") ? "digital" : "fisica";
};
const mapEstado = (s: string): "Borrador" | "En revisión" | "Recibida" => {
  const t = s.toLowerCase();
  if (t.includes("recib")) return "Recibida";
  if (t.includes("borrador")) return "Borrador";
  return "En revisión";
};
const nombre = (u: unknown) => {
  const x = (Array.isArray(u) ? u[0] : u) as { nombre?: string; apellido?: string } | null;
  return x ? [x.nombre, x.apellido].filter(Boolean).join(" ") || null : null;
};

/** GET /api/transferencias/[id] → detalle con inventario (alimenta la pantalla de detalle) */
export async function GET(_req: Request, ctx: Ctx) {
  try {
    // const user = await requireUser(_req);
    const id = Number((await ctx.params).id);
    if (!Number.isInteger(id) || id <= 0) return errorFormulario("Id no válido", 400);

    const { data: t, error } = await supabase
      .from("transferencia")
      .select(`
        id, codigo, anio, tipo, estado, funcionario_entrega, descripcion, contenido, ubicacion_texto, unidades,
        registrado_en, recibido_en,
        dependencia:dependencia_id(nombre),
        recibidor:usuario!transferencia_recibido_por_fkey(nombre, apellido),
        registrador:usuario!transferencia_registrado_por_fkey(nombre, apellido)
      `)
      .eq("id", id).maybeSingle();
    if (error) throw error;
    if (!t) return errorFormulario("No existe la transferencia", 404);

    const { data: items, error: e2 } = await supabase
      .from("inventario_item").select("*").eq("transferencia_id", id)
      .order("fila_origen", { ascending: true });
    if (e2) throw e2;

    const dep = Array.isArray(t.dependencia) ? t.dependencia[0] : t.dependencia;
    return NextResponse.json({
      id: t.id,
      codigo: t.codigo,
      dependencia: dep?.nombre ?? "—",
      anio: t.anio,
      tipo: mapTipo(String(t.tipo)),
      estado: mapEstado(String(t.estado)),
      contenido: t.contenido,
      responsable: t.funcionario_entrega,
      recibio: nombre(t.recibidor) ?? nombre(t.registrador),
      fecha: String(t.recibido_en ?? t.registrado_en).slice(0, 10),
      ubicacion: t.ubicacion_texto,
      unidades: t.unidades ?? 0,
      carpetas: (items ?? []).map(i => ({
        caja: i.caja, carpeta: i.carpeta_tomo, asunto: i.asunto_texto,
        fechaInicial: i.fecha_inicial, fechaFinal: i.fecha_final,
        folios: i.folios, docs: i.docs ?? null,
        consecutivoDesde: i.consecutivo_desde, consecutivoHasta: i.consecutivo_hasta,
        descripcion: i.descripcion ?? i.observaciones ?? null,
      })),
    });
  } catch (e) {
    console.error("GET /api/transferencias/[id]", e);
    return errorSistema("INTERNO", 500, { detalle: "no se pudo cargar la transferencia" });
  }
}