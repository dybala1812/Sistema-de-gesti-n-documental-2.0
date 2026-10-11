/**
 * POST /api/n8n/recordatorios/resumen-dia — #19 · F4
 * Lista (array) de comunicaciones activas para el resumen diario de Archivo Central.
 * Función SQL: n8n_resumen_dia. Convenciones en lib/n8n.ts.
 */
import { rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_resumen_dia",
  lista: true,
});
