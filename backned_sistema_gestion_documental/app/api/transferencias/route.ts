import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase"; // AJUSTA: nombre/ruta real de tu cliente de Supabase
import { errorFormulario, errorSistema } from "@/lib/errors";
// import { requireUser } from "@/lib/auth"; // AJUSTA: la validación que usan las rutas de comunicaciones

const TIPOS = ["fisica", "digital", "ambas"] as const;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Fila técnica del inventario de una transferencia digital (no es una caja física). */
const CAJA_DIGITAL = "Digital";

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
    // El Excel que entrega la dependencia se guarda tal cual como acta (no se lee fila por fila):
    // el inventario detallado es opcional.
    const carpetas: unknown[] = Array.isArray(b.carpetas) ? b.carpetas : [];
    if (carpetas.length > 5000)
      return errorFormulario("El inventario es demasiado grande", 400);
    const observaciones = String(b.observaciones ?? "").trim();
    if (observaciones.length > 2000)
      return errorFormulario("Las observaciones no pueden pasar de 2.000 caracteres", 400, { campo: "observaciones", tipo: "rango" });
    // Acta de entrega: el archivo que entregó la dependencia, ya subido con POST /api/archivos.
    const actaId = b.acta_archivo_id ? String(b.acta_archivo_id) : null;
    if (actaId && !UUID_RE.test(actaId))
      return errorFormulario("El acta de entrega no es válida", 400, { campo: "acta_archivo_id", tipo: "formato" });

    // Física: las cajas no se suben, se quedan en Archivo Central. Se exige dónde quedó guardada cada
    // una: carro, estante y bandeja escritos en esta carga (D-25: no salen de un catálogo, cada caja
    // puede quedar en un sitio distinto), y se guardan en su fila del inventario.
    type Posicion = { carro: string; estante: string; bandeja: string };
    const ubicacionDeCaja = new Map<string, Posicion>();
    if (b.tipo === "fisica") {
      const lista: { caja?: unknown; carro?: unknown; estante?: unknown; bandeja?: unknown }[] = Array.isArray(b.cajas) ? b.cajas : [];
      if (lista.length === 0)
        return errorFormulario("Indica cuántas cajas entregó la dependencia y dónde quedaron", 400, { campo: "cajas", tipo: "obligatorio" });
      if (lista.length > 2000)
        return errorFormulario("Máximo 2.000 cajas por transferencia", 400, { campo: "cajas", tipo: "rango" });
      const sinUbicacion: string[] = [];
      const texto = (v: unknown) => String(v ?? "").trim().slice(0, 60);
      for (const c of lista) {
        const caja = texto(c?.caja);
        if (!caja) continue;
        const pos = { carro: texto(c?.carro), estante: texto(c?.estante), bandeja: texto(c?.bandeja) };
        if (pos.carro && pos.estante && pos.bandeja) ubicacionDeCaja.set(caja, pos);
        else sinUbicacion.push(caja);
      }
      if (sinUbicacion.length > 0)
        return errorFormulario(`Falta el carro, estante o bandeja de la caja ${sinUbicacion.slice(0, 5).join(", ")}${sinUbicacion.length > 5 ? "…" : ""}`, 400, { campo: "cajas", tipo: "obligatorio" });
    }

    // registrar_transferencia (en Supabase) exige al menos una fila de inventario. Sin detalle:
    // física → una fila por caja (con su ubicación); digital → una fila técnica "Digital"
    // (los documentos quedan ligados a la transferencia y el detalle los muestra en su lugar).
    const inventario = carpetas.length > 0 ? carpetas
      : b.tipo === "fisica" ? [...ubicacionDeCaja.keys()].map(caja => ({ caja }))
      : [{ caja: CAJA_DIGITAL, descripcion: "Documentos en digital: ver el acta de entrega" }];

    const { data, error } = await supabase.rpc("registrar_transferencia", {
      p: {
        dependencia: b.dependencia, anio: b.anio, tipo: b.tipo,
        contenido: b.contenido, responsable: b.responsable, ubicacion: b.ubicacion ?? "",
        carpetas: inventario,
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

    const creada = (Array.isArray(data) ? data[0] : data) as { id?: number } | null;
    const avisos: string[] = [];
    if (creada?.id && ubicacionDeCaja.size > 0) {
      // Cada caja queda en el inventario con su ubicación: se actualiza si vino en el detalle, si no se crea.
      const { data: existentes, error: eEx } = await supabase
        .from("inventario_item").select("caja").eq("transferencia_id", creada.id);
      if (eEx) throw eEx;
      const conFilas = new Set((existentes ?? []).map(i => String(i.caja)));
      const nuevas: ({ transferencia_id: number; caja: string; fila_origen: number } & Posicion)[] = [];
      let fila = 1;
      for (const [caja, pos] of ubicacionDeCaja) {
        if (conFilas.has(caja)) {
          const { error: eU } = await supabase
            .from("inventario_item").update(pos).eq("transferencia_id", creada.id).eq("caja", caja);
          if (eU) { console.error("POST /api/transferencias (ubicación)", eU); avisos.push(`no se guardó la ubicación de la caja ${caja}`); }
        } else {
          nuevas.push({ transferencia_id: creada.id, caja, ...pos, fila_origen: fila });
        }
        fila++;
      }
      if (nuevas.length > 0) {
        const { error: eN } = await supabase.from("inventario_item").insert(nuevas);
        if (eN) { console.error("POST /api/transferencias (cajas)", eN); avisos.push("no se guardaron las cajas con su ubicación"); }
      }
    }
    if (creada?.id) {
      // Física: unidades = cajas. Digital: unidades = documentos que se van a subir.
      const unidades = b.tipo === "fisica" ? ubicacionDeCaja.size : Number(b.total_documentos) || null;
      const cambios: Record<string, unknown> = {};
      if (unidades) cambios.unidades = unidades;
      if (observaciones) cambios.descripcion = observaciones;
      if (Object.keys(cambios).length > 0) {
        const { error: eT } = await supabase.from("transferencia").update(cambios).eq("id", creada.id);
        if (eT) { console.error("POST /api/transferencias (datos)", eT); avisos.push("no se guardaron las observaciones o la cantidad"); }
      }
    }
    if (actaId && creada?.id) {
      const { error: eActa } = await supabase
        .from("transferencia").update({ acta_archivo_id: actaId }).eq("id", creada.id);
      if (eActa) {
        console.error("POST /api/transferencias (acta)", eActa);
        avisos.push("no se pudo asociar el acta de entrega");
      }
    }
    if (avisos.length > 0) {
      // La transferencia ya quedó registrada: se avisa, sin deshacerla.
      return NextResponse.json({ ...creada, aviso: `La transferencia quedó registrada, pero ${avisos.join("; ")}` }, { status: 201 });
    }
    return NextResponse.json(data, { status: 201 });
  } catch (e) {
    console.error("POST /api/transferencias", e);
    return errorSistema("INTERNO", 500, { detalle: "no se pudo registrar la transferencia" });
  }
}