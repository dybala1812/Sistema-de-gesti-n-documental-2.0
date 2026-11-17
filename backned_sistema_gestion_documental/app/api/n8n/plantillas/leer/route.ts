/**
 * POST /api/n8n/plantillas/leer — F5
 * Lee una plantilla de correo por código (antes, nodo de Supabase; I-21).
 * Función SQL: n8n_leer_plantilla. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_leer_plantilla",
  parametros: (b) => ({ p_codigo: leer.texto(b, "codigo", true) }),
});
