/**
 * POST /api/n8n/triaje/actualizar — F7 (PATCH /correos/:id)
 * Marca como leído o no leído y reclasifica. Función SQL: n8n_triaje_actualizar. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_triaje_actualizar",
  parametros: (b) => ({
    p_id: leer.entero(b, "id", true),
    p_leido: leer.booleano(b, "leido"),
    p_categoria: leer.texto(b, "categoria"),
    p_prioridad: leer.texto(b, "prioridad"),
  }),
});
