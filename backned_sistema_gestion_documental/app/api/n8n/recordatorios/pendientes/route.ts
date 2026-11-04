/**
 * POST /api/n8n/recordatorios/pendientes — #17 · F4
 * Lista (array) de dependencias con sus comunicaciones vencidas por recordar.
 * Función SQL: n8n_recordatorios_pendientes. Convenciones en lib/n8n.ts.
 */
import { rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_recordatorios_pendientes",
  lista: true,
});
