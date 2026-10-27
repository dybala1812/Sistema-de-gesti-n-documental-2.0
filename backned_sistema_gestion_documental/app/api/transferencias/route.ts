import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase"; // AJUSTA: nombre/ruta real de tu cliente de Supabase
import { errorFormulario, errorSistema } from "@/lib/errors";
// import { requireUser } from "@/lib/auth"; // AJUSTA: la validación que usan las rutas de comunicaciones

const TIPOS = ["fisica", "digital", "ambas"] as const;

// Los enums se interpretan por texto, así que no importa cómo se llamen exactamente en la base
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

/** GET /api/transferencias?anio=2024 → lista para la pantalla "Transferencias documentales" */
export async function GET(req: Request) {
  try {
    // const user = await requireUser(req);
    const anio = new URL(req.url).searchParams.get("anio");
    let q = supabase
      .from("transferencia")
      .select("id, codigo, anio, tipo, estado, funcionario_entrega, descripcion, contenido, unidades, registrado_en, recibido_en, dependencia:dependencia_id(nombre)")
      .is("anulado_en", null)
      .order("registrado_en", { ascending: true });
    if (anio) q = q.eq("anio", Number(anio));

    const { data, error } = await q;
    if (error) throw error;
    const filas = data ?? [];

    // Documentos de cada transferencia que siguen por clasificar
    const ids = filas.map(t => t.id);
    const porClasificar = new Map<number, number>();
    if (ids.length > 0) {
      const { data: docs, error: e2 } = await supabase
        .from("documento").select("transferencia_id")
        .in("transferencia_id", ids).eq("estado", "por_clasificar");
      if (e2) throw e2;
      for (const d of docs ?? []) porClasificar.set(d.transferencia_id, (porClasificar.get(d.transferencia_id) ?? 0) + 1);
    }

    return NextResponse.json(
      filas.map(t => {
        const dep = Array.isArray(t.dependencia) ? t.dependencia[0] : t.dependencia;
        return {
          id: t.id,
          codigo: t.codigo,
          dependencia: dep?.nombre ?? "—",
          anio: t.anio,
          tipo: mapTipo(String(t.tipo)),
          estado: mapEstado(String(t.estado)),
          fecha: String(t.recibido_en ?? t.registrado_en).slice(0, 10),
          entrega: t.funcionario_entrega,
          contenido: t.contenido ?? "Documentos",
          detalle: t.descripcion ?? "",
          unidades: t.unidades ?? 0,
          porClasificar: porClasificar.get(t.id) || undefined,
        };
      })
    );
  } catch (e) {
    console.error("GET /api/transferencias", e);
    return errorSistema("INTERNO", 500, { detalle: "no se pudieron cargar las transferencias" });
  }
}

/** POST /api/transferencias → crea y registra la transferencia con su inventario (todo en una transacción) */
export async function POST(req: Request) {
  try {
    // const user = await requireUser(req);   // AJUSTA: protege la ruta
    const b = await req.json().catch(() => null);
    if (!b) return errorFormulario("Cuerpo de la petición no válido", 400);

    // Validación básica (la regla de fondo —dos años, fechas, dependencia— la repite la función SQL)
    if (!b.dependencia || !String(b.contenido ?? "").trim() || !String(b.responsable ?? "").trim())
      return errorFormulario("Faltan datos obligatorios", 400);
    if (!TIPOS.includes(b.tipo)) return errorFormulario("Tipo de entrega no válido", 400);
    if (!Array.isArray(b.carpetas) || b.carpetas.length === 0)
      return errorFormulario("Falta el inventario FUID", 400);
    if (b.carpetas.length > 5000)
      return errorFormulario("El inventario es demasiado grande", 400);

    const { data, error } = await supabase.rpc("registrar_transferencia", {
      p: {
        dependencia: b.dependencia, anio: b.anio, tipo: b.tipo,
        contenido: b.contenido, responsable: b.responsable, ubicacion: b.ubicacion ?? "",
        carpetas: b.carpetas,
        usuario_id: null, // AJUSTA: id de la tabla `usuario` del usuario autenticado (user.id)
      },
    });

    if (error) {
      // Los errores "raise exception" de la función son de validación: se devuelven con su mensaje
      const validacion = error.code === "P0001";
      if (!validacion) console.error("POST /api/transferencias", error);
      return validacion
        ? errorFormulario(error.message, 400)
        : errorSistema("BASE_DATOS", 500, { detalle: "no se pudo registrar la transferencia" });
    }
    return NextResponse.json(data, { status: 201 });
  } catch (e) {
    console.error("POST /api/transferencias", e);
    return errorSistema("INTERNO", 500, { detalle: "no se pudo registrar la transferencia" });
  }
}