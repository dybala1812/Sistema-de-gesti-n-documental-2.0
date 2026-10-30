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
        acta:acta_archivo_id(id, nombre_original, mime, tamano_bytes),
        dependencia:dependencia_id(nombre),
        recibidor:usuario!transferencia_recibido_por_fkey(nombre, apellido),
        registrador:usuario!transferencia_registrado_por_fkey(nombre, apellido)
      `)
      .eq("id", id).maybeSingle();
    if (error) throw error;
    if (!t) return errorFormulario("No existe la transferencia", 404);

    const { data: items, error: e2 } = await supabase
      .from("inventario_item").select("*, ubicacion:ubicacion_id(id, carro, estante, bandeja, bodega, modulo)").eq("transferencia_id", id)
      .order("fila_origen", { ascending: true });
    if (e2) throw e2;

    // Transferencia digital: los archivos que entregó la dependencia, guardados con la transferencia
    // (migración 22). Si la migración aún no está aplicada, el detalle se muestra igual, sin archivos.
    let archivos: { id: string; nombre: string; mime: string; tamano: number }[] = [];
    let avisoArchivos: string | null = null;
    if (String(t.tipo) === "digital") {
      const { data: filas, error: e3 } = await supabase
        .from("transferencia_archivo").select("archivo:archivo_id(id, nombre_original, mime, tamano_bytes)")
        .eq("transferencia_id", id).is("anulado_en", null).order("id", { ascending: true });
      if (e3 && (e3.code === "42P01" || e3.code === "PGRST205")) {
        avisoArchivos = "Falta aplicar la migración 20261022000000_transferencia_archivos.sql en Supabase";
      } else if (e3) {
        throw e3;
      }
      archivos = (filas ?? []).flatMap(f => {
        const a = Array.isArray(f.archivo) ? f.archivo[0] : f.archivo;
        return a ? [{ id: a.id, nombre: a.nombre_original, mime: a.mime, tamano: Number(a.tamano_bytes) || 0 }] : [];
      });
    }

    const dep = Array.isArray(t.dependencia) ? t.dependencia[0] : t.dependencia;
    const acta = Array.isArray(t.acta) ? t.acta[0] : t.acta;
    return NextResponse.json({
      /** Acta de entrega: el archivo que entregó la dependencia (descarga con GET /api/archivos/{id}). */
      acta: acta ? { id: acta.id, nombre: acta.nombre_original, mime: acta.mime, tamano: Number(acta.tamano_bytes) || 0 } : null,
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
      observaciones: t.descripcion ?? null,
      unidades: t.unidades ?? 0,
      carpetas: (items ?? []).map(i => ({
        caja: i.caja, carpeta: i.carpeta_tomo, asunto: i.asunto_texto,
        fechaInicial: i.fecha_inicial, fechaFinal: i.fecha_final,
        folios: i.folios, docs: i.docs ?? null,
        consecutivoDesde: i.consecutivo_desde, consecutivoHasta: i.consecutivo_hasta,
        descripcion: i.descripcion ?? i.observaciones ?? null,
        /** Dónde quedó guardada la caja: carro · estante · bandeja escritos en la carga (D-25);
         *  las cajas viejas sin esos datos usan la ubicación del catálogo. */
        ubicacion: i.carro || i.estante || i.bandeja
          ? { id: 0, carro: i.carro ?? null, estante: i.estante ?? null, bandeja: i.bandeja ?? null }
          : (Array.isArray(i.ubicacion) ? i.ubicacion[0] : i.ubicacion) ?? null,
      })),
      /** Digital: los archivos de la transferencia (se ven y descargan con GET /api/archivos/{id}). */
      archivos,
      aviso_archivos: avisoArchivos,
    });
  } catch (e) {
    console.error("GET /api/transferencias/[id]", e);
    return errorSistema("INTERNO", 500, { detalle: "no se pudo cargar la transferencia" });
  }
}