/**
 * POST /api/n8n/correos/triaje — F1
 * Guarda la categoría, prioridad y resumen que sugirió la IA. Idempotente; no pisa lo que corrigió una persona.
 * Función SQL: n8n_guardar_triaje. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_guardar_triaje",
  parametros: (b) => ({
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
    p_categoria: leer.texto(b, "categoria"),
    p_prioridad: leer.texto(b, "prioridad"),
    p_resumen: leer.texto(b, "resumen"),
  }),
  vacio: { id: null },
});
