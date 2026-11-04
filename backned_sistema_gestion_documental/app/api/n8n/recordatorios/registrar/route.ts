/**
 * POST /api/n8n/recordatorios/registrar — #18 · F4
 * Registra los recordatorios enviados (marca por_escalar tras el máximo).
 * Función SQL: n8n_registrar_recordatorios. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_recordatorios",
  parametros: (b) => ({
    p_ids: leer.enteros(b, "ids"),
    p_message_id: leer.texto(b, "message_id"),
  }),
});
