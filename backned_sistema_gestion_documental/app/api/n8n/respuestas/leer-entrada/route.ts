/**
 * POST /api/n8n/respuestas/leer-entrada — #11 · F3
 * Lee la comunicación de entrada y sus adjuntos ([{archivo_id, de_dependencia}]). Si no existe: {"id": null}.
 * Función SQL: n8n_leer_entrada. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_leer_entrada",
  parametros: (b) => ({
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
  }),
  vacio: { id: null },
});
