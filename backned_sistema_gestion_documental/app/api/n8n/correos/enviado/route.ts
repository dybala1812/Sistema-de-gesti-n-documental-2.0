/**
 * POST /api/n8n/correos/enviado
 * F5 registra una copia de cada correo que envía (para verlo desde el historial).
 * Idempotente por message_id. Función SQL: n8n_registrar_correo_enviado (migración 14).
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_correo_enviado",
  parametros: (b) => ({
    p_message_id: leer.texto(b, "message_id", true),
    p_para: leer.texto(b, "para", true),
    p_asunto: leer.texto(b, "asunto", true),
    p_cuerpo: leer.texto(b, "cuerpo"),
    p_plantilla: leer.texto(b, "plantilla"),
    p_comunicacion_id: leer.entero(b, "comunicacion_id"),
    p_consecutivos: leer.textos(b, "consecutivos"),
    p_archivo_ids: leer.uuids(b, "archivo_ids"),
    p_enviado_en: leer.fecha(b, "enviado_en"),
  }),
});
