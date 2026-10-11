import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { SolicitudInvalida, leer, parseBody, idRuta } from "../../../../../lib/n8n";
import { handleError, jsonResponse, notFound, forbidden, errorResponse } from "../../../../../lib/errors";

/** Suma días hábiles (salta sábados y domingos) a partir de una fecha local. */
function sumarDiasHabiles(desde: Date, dias: number): Date {
  const fecha = new Date(desde);
  let restantes = dias;
  while (restantes > 0) {
    fecha.setDate(fecha.getDate() + 1);
    const dia = fecha.getDay();
    if (dia !== 0 && dia !== 6) restantes--;
  }
  return fecha;
}

async function remitirComunicacion(
  comunicacionId: number,
  dependenciaId: number,
  plazoDiasHabiles: number | null,
  mensaje: string,
  messageIdEnviado: string | null,
): Promise<void> {
  const { data: plazoParam } = await supabase.rpc("fn_parametro_entero", {
    p_clave: "plazo_respuesta_dias_habiles",
  });
  const plazo = plazoDiasHabiles ?? (plazoParam ? Number(plazoParam) : null) ?? 5;
  const fechaLimite = sumarDiasHabiles(new Date(), plazo).toISOString().split("T")[0];

  const { error: updateError } = await supabase
    .from("comunicacion")
    .update({
      dependencia_id: dependenciaId,
      fecha_limite: fechaLimite,
      estado: "remitida",
    })
    .eq("id", comunicacionId)
    .eq("estado", "nueva");

  if (updateError) {
    throw Object.assign(new Error(updateError.message), { status: 422, code: updateError.code });
  }

  const { data: eventoRemision } = await supabase
    .from("comunicacion_evento")
    .select("id")
    .eq("comunicacion_id", comunicacionId)
    .eq("tipo", "remision")
    .order("id", { ascending: false })
    .limit(1)
    .single();

  if (eventoRemision) {
    const detalle: Record<string, unknown> = { plazo_dias_habiles: plazo };
    if (mensaje) detalle.mensaje = mensaje;
    await supabase
      .from("comunicacion_evento")
      .update({
        message_id: messageIdEnviado,
        detalle,
      })
      .eq("id", eventoRemision.id);
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede remitir comunicaciones");
    }

    const comunicacionId = idRuta(await params);
    const b = await parseBody(request);
    const dependenciaId = leer.entero(b, "dependencia_id", true) as number;
    const plazoDiasHabiles = leer.entero(b, "plazo_dias_habiles");
    const mensaje = leer.texto(b, "mensaje") ?? "";
    const messageIdEnviado = leer.texto(b, "message_id_enviado");

    const previa = await obtenerComunicacion(comunicacionId);
    if (!previa) return notFound("Comunicación no encontrada");
    if (previa.estado !== "nueva") {
      return errorResponse(`No se puede remitir una comunicación en estado "${previa.estado}"`);
    }

    // TODO: migrar a fn_remitir_comunicacion_usuario cuando se aplique
    // database/supabase/migrations/20261007000700_backend_helpers.sql.
    await remitirComunicacion(comunicacionId, dependenciaId, plazoDiasHabiles, mensaje, messageIdEnviado);

    const actualizada = await obtenerComunicacion(comunicacionId);
    return jsonResponse(actualizada);
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
