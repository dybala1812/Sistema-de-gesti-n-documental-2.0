/**
 * POST /api/n8n/correos/rebote — #2 · F1
 * Registra un rebote (correo no entregado) en las comunicaciones citadas y lo audita.
 * Función SQL: n8n_registrar_rebote. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_rebote",
  parametros: (b) => ({
    p_ids: leer.textos(b, "ids"),
    p_de: leer.texto(b, "de"),
    p_asunto: leer.texto(b, "asunto"),
  }),
});
