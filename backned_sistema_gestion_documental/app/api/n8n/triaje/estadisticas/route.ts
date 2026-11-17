/**
 * POST /api/n8n/triaje/estadisticas — F7 (GET /estadisticas)
 * Contadores por categoría y prioridad, no leídos y urgentes.
 * Función SQL: n8n_triaje_estadisticas. Convenciones en lib/n8n.ts.
 */
import { rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({ funcion: "n8n_triaje_estadisticas" });
