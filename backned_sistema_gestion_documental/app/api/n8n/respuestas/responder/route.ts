/**
 * POST /api/n8n/respuestas/responder — #12 · F3
 * Registra la salida SAL y cierra la entrada (después de enviar el correo al remitente).
 * Función SQL: n8n_responder. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N, usuario } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_responder",
  parametros: (b) => ({
    p_usuario: usuario(b),
    p_entrada_id: leer.entero(b, "entrada_id", true),
    p_asunto: leer.texto(b, "asunto", true),
    p_cuerpo: leer.texto(b, "cuerpo", true),
    p_message_id: leer.texto(b, "message_id"),
    p_archivos: leer.uuids(b, "archivos"),
  }),
});
