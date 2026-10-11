/**
 * POST /api/n8n/correos/nuevo — #4 · F1
 * Registra un correo nuevo como comunicación de entrada (consecutivo ENT) con sus adjuntos. Idempotente por Message-ID.
 * Función SQL: n8n_registrar_correo_nuevo. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_correo_nuevo",
  parametros: (b) => ({
    p_message_id: leer.texto(b, "message_id", true),
    p_de_nombre: leer.texto(b, "de_nombre"),
    p_de_correo: leer.texto(b, "de_correo", true),
    p_asunto: leer.texto(b, "asunto") ?? "(sin asunto)",
    p_cuerpo: leer.texto(b, "cuerpo"),
    p_recibido_en: leer.fecha(b, "recibido_en") ?? new Date().toISOString(),
    p_in_reply_to: leer.texto(b, "in_reply_to"),
    p_archivo_ids: leer.uuids(b, "archivo_ids"),
    p_adjuntos_omitidos: leer.json(b, "adjuntos_omitidos") ?? [],
  }),
});
