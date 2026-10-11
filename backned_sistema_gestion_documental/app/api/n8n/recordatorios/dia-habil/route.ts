/**
 * POST /api/n8n/recordatorios/dia-habil — #16 · F4
 * Indica si hoy es día hábil: {"habil": true|false}.
 * Función SQL: n8n_es_dia_habil. Convenciones en lib/n8n.ts.
 */
import { rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_es_dia_habil",
});
