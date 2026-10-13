import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";          // AJUSTA: el nombre/ruta real de tu cliente de Supabase
// import { requireUser } from "@/lib/auth";        // AJUSTA: descomenta con la función que ya usas en comunicaciones

const TIPOS = ["fisica", "digital", "ambas"] as const;

/** GET /api/transferencias?anio=2024  → lista (opcionalmente filtrada por año) */
export async function GET(req: Request) {
  try {
    // const user = await requireUser(req);          // AJUSTA: protege la ruta antes de usarla en serio

    const anio = new URL(req.url).searchParams.get("anio");
    let q = supabase.from("transferencias").select("*").order("fecha", { ascending: true, nullsFirst: false });
    if (anio) q = q.eq("anio", Number(anio));

    const { data, error } = await q;
    if (error) throw error;

    // Mismo formato que espera Transferencias.tsx en el frontend
    return NextResponse.json(
      (data ?? []).map(t => ({
        codigo: t.codigo,
        dependencia: t.dependencia,
        anio: t.anio,
        tipo: t.tipo,
        estado: t.estado,
        fecha: t.fecha,
        entrega: t.responsable,
        contenido: t.contenido,
        detalle: t.detalle ?? "",
        unidades: t.unidades,
        porClasificar: t.por_clasificar || undefined,
      }))
    );
  } catch (e) {
    console.error("GET /api/transferencias", e);
    return NextResponse.json({ mensaje: "No se pudieron cargar las transferencias" }, { status: 500 });
  }
}

/** POST /api/transferencias → crea un BORRADOR (el código TR-… se asigna al registrar) */
export async function POST(req: Request) {
  try {
    // const user = await requireUser(req);
    const body = await req.json();

    const { dependencia, anio, tipo, contenido, responsable, ubicacion } = body ?? {};
    const anioMaximo = new Date().getFullYear() - 2; // regla de los dos años

    if (!dependencia || !contenido || !String(responsable ?? "").trim())
      return NextResponse.json({ mensaje: "Faltan datos obligatorios" }, { status: 400 });
    if (!TIPOS.includes(tipo))
      return NextResponse.json({ mensaje: "Tipo de entrega no válido" }, { status: 400 });
    if (!Number.isInteger(anio) || anio > anioMaximo)
      return NextResponse.json({ mensaje: `Solo se puede transferir hasta ${anioMaximo}` }, { status: 400 });
    if ((tipo === "fisica" || tipo === "ambas") && !String(ubicacion ?? "").trim())
      return NextResponse.json({ mensaje: "Falta la ubicación física" }, { status: 400 });

    const { data, error } = await supabase
      .from("transferencias")
      .insert({
        dependencia, anio, tipo, contenido,
        responsable: String(responsable).trim(),
        ubicacion: ubicacion ?? null,
        estado: "Borrador",
        creado_por: "sistema", // AJUSTA: user.email (o el id) cuando tengas requireUser
      })
      .select("id")
      .single();
    if (error) throw error;

    return NextResponse.json({ id: data.id }, { status: 201 });
  } catch (e) {
    console.error("POST /api/transferencias", e);
    return NextResponse.json({ mensaje: "No se pudo guardar el borrador" }, { status: 500 });
  }
}