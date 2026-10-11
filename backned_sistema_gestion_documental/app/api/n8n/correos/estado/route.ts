/**
 * POST /api/n8n/correos/estado — #1 · F1
 * Estado de un correo entrante: ya procesado, comunicación a la que responde, dependencia remitente y si es del buzón propio.
 * Función SQL: n8n_estado_correo. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_estado_correo",
  parametros: (b) => ({
    p_message_id: leer.texto(b, "message_id", true),
    p_asunto: leer.texto(b, "asunto"),
    p_in_reply_to: leer.texto(b, "in_reply_to"),
    p_de_correo: leer.texto(b, "de_correo"),
  }),
});
