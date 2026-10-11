/**
 * POST /api/n8n/correos/respuesta-dependencia — #3 · F1
 * Registra la respuesta de una dependencia. Si el estado no lo permite responde 409 con "RN-AC-09" (F1 la manda a sin asociar).
 * Función SQL: n8n_registrar_respuesta_dependencia. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_respuesta_dependencia",
  parametros: (b) => ({
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
    p_de_correo: leer.texto(b, "de_correo"),
    p_asunto: leer.texto(b, "asunto"),
    p_cuerpo: leer.texto(b, "cuerpo"),
    p_message_id: leer.texto(b, "message_id"),
    p_recibido_en: leer.fecha(b, "recibido_en"),
    p_archivo_ids: leer.uuids(b, "archivo_ids"),
    p_adjuntos_omitidos: leer.json(b, "adjuntos_omitidos") ?? [],
  }),
});
