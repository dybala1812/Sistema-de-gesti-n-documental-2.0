/**
 * POST /api/comunicaciones/[id]/responder-directo
 * Permite responder directamente al remitente sin pasar por una dependencia.
 *
 * Excepción documentada a RN-AC-09: una entrada en estado "nueva" puede pasar a
 * "respondida_dependencia" y cerrarse con F3 cuando Archivo Central responde al remitente.
 *
 * El backend:
 *  1. Actualiza la comunicación a "respondida_dependencia" y registra un evento
 *     "respuesta_dependencia" marcado como directo.
 *  2. Dispara el webhook de n8n F3 para que envíe el correo y cierre la entrada.
 */
import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { dispararWebhookN8N } from "../../../../../lib/n8nWebhook";
import { SolicitudInvalida, idRuta, leer, parseBody } from "../../../../../lib/n8n";
import { errorResponse, errorSistema, forbidden, handleError, jsonResponse, notFound } from "../../../../../lib/errors";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede responder comunicaciones");
    }

    const comunicacionId = idRuta(await params);
    const com = await obtenerComunicacion(comunicacionId);
    if (!com) return notFound("Comunicación no encontrada");

    if (com.tipo !== "ENT") {
      return errorResponse("Solo se responden comunicaciones de entrada", 409);
    }
    if (com.estado === "cerrada" || com.estado === "anulada") {
      return errorResponse(`No se puede responder una comunicación "${com.estado}"`, 409);
    }

    const b = await parseBody(request);
    const asunto = leer.texto(b, "asunto");
    const cuerpo = leer.texto(b, "cuerpo", true);
    const adjuntos = leer.uuids(b, "adjuntos");

    // Se comprueba ANTES de tocar la base de datos: si falta el webhook, el correo no puede salir
    // y la comunicación no debe quedar marcada como respondida.
    const url = process.env.N8N_WEBHOOK_RESPONDER_URL;
    if (!url) {
      return errorSistema("CONFIGURACION", 503, {
        detalle: "defina N8N_WEBHOOK_RESPONDER_URL en el .env.local del backend (URL del webhook de F3: .../webhook/bandeja/responder) y reinicie el backend",
      });
    }

    // Prepara la comunicación para que F3 la acepte.
    const { error: rpcError } = await supabase.rpc("fn_responder_directo", {
      p_usuario_id: usuario.id,
      p_comunicacion_id: comunicacionId,
      p_mensaje: cuerpo,
    });
    if (rpcError) {
      // La función no existe en la base: falta aplicar la migración (no es un error del usuario).
      if (rpcError.code === "PGRST202") {
        return errorSistema("MIGRACION", 500, {
          detalle: "no existe fn_responder_directo; ejecute en el SQL Editor 20261011000000_f4_manual_y_correo_adicional.sql y 20261012000000_responder_directo_transicion.sql",
        });
      }
      // Reglas de negocio de la base (RN-AC-xx / RF-AC-xx) → conflicto de estado, no datos inválidos.
      const esRegla = /(RN|RF)-AC-\d+/.test(rpcError.message) || rpcError.code === "P0001";
      return errorResponse(rpcError.message, esRegla ? 409 : 400, { codigo: rpcError.code });
    }

    let resultado: unknown;
    try {
      resultado = await dispararWebhookN8N(url, {
        comunicacion_id: comunicacionId,
        usuario_id: usuario.id,
        asunto,
        cuerpo,
        destinatario: com.remitente_correo,
        archivo_ids: adjuntos,
      });
    } catch (err) {
      // La comunicación ya quedó lista (respondida_dependencia) pero el correo no salió.
      // Es seguro reintentar: fn_responder_directo acepta una entrada ya preparada.
      return errorSistema("SERVICIO_EXTERNO", 502, {
        detalle: "n8n no pudo enviar la respuesta; puede volver a intentarlo",
        interno: err instanceof Error ? err.message : String(err),
      });
    }

    return jsonResponse({ ok: true, comunicacion_id: comunicacionId, n8n: resultado });
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
