/**
 * POST /api/n8n/correos/adicional
 * Registra un correo adicional enviado manualmente como evento de la comunicación.
 * Función SQL: n8n_registrar_correo_adicional. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N, usuario } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_correo_adicional",
  parametros: (b) => ({
    p_usuario: usuario(b),
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
    p_destinatario_tipo: leer.texto(b, "destinatario_tipo", true),
    p_destinatario_correo: leer.texto(b, "destinatario_correo"),
    p_asunto: leer.texto(b, "asunto", true),
    p_cuerpo: leer.texto(b, "cuerpo", true),
    p_archivos: leer.uuids(b, "archivos"),
    p_message_id: leer.texto(b, "message_id"),
  }),
});
