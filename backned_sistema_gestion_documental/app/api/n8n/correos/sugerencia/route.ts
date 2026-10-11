/**
 * POST /api/n8n/correos/sugerencia — #5 · F1
 * Guarda una sugerencia (nota) en la comunicación. Si detalle es null no inserta y responde {"id": null}.
 * Función SQL: n8n_guardar_sugerencia. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_guardar_sugerencia",
  parametros: (b) => ({
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
    p_detalle: leer.json(b, "detalle"),
  }),
  vacio: { id: null },
});
