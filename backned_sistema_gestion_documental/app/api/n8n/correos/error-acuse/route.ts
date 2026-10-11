/**
 * POST /api/n8n/correos/error-acuse — #7 · F1
 * Registra que el acuse de recibo no se pudo enviar.
 * Función SQL: n8n_registrar_error_acuse. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_error_acuse",
  parametros: (b) => ({
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
    p_error: leer.texto(b, "error"),
  }),
  vacio: { id: null },
});
