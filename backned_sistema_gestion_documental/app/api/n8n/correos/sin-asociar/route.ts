/**
 * POST /api/n8n/correos/sin-asociar — #6 · F1
 * Guarda un correo en "Correos sin asociar". Idempotente por Message-ID (insertados: 0 si ya estaba).
 * Función SQL: n8n_guardar_sin_asociar. Convenciones en lib/n8n.ts.
 */
import { leer, SolicitudInvalida, rutaN8N } from "../../../../../lib/n8n";

const MOTIVOS = ["otro", "etiqueta_no_coincide", "sin_etiqueta", "remitente_externo_sin_etiqueta"];

export const POST = rutaN8N({
  funcion: "n8n_guardar_sin_asociar",
  parametros: (b) => {
    const motivo = leer.texto(b, "motivo", true);
    if (!MOTIVOS.includes(motivo as string)) {
      throw new SolicitudInvalida(`motivo debe ser uno de: ${MOTIVOS.join(", ")}`);
    }
    return {
      p_message_id: leer.texto(b, "message_id", true),
      p_in_reply_to: leer.texto(b, "in_reply_to"),
      p_de_nombre: leer.texto(b, "de_nombre"),
      p_de_correo: leer.texto(b, "de_correo", true),
      p_asunto: leer.texto(b, "asunto"),
      p_cuerpo: leer.texto(b, "cuerpo"),
      p_recibido_en: leer.fecha(b, "recibido_en"),
      p_motivo: motivo,
      p_posible_comunicacion_id: leer.entero(b, "posible_comunicacion_id"),
      p_adjuntos: leer.uuids(b, "adjuntos"),
    };
  },
});
