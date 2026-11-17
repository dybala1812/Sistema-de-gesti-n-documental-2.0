/**
 * POST /api/n8n/parametros/leer — F6
 * Lee un parámetro por clave (antes, nodo de Supabase; I-21).
 * Función SQL: n8n_leer_parametro. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_leer_parametro",
  parametros: (b) => ({ p_clave: leer.texto(b, "clave", true) }),
});
