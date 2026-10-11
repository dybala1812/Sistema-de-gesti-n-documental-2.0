/**
 * POST /api/n8n/auditoria/error-flujo — #15 · F6
 * Registra en la auditoría el error de una ejecución de cualquier flujo.
 * Función SQL: n8n_auditar_error_flujo. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_auditar_error_flujo",
  parametros: (b) => ({
    p_flujo: leer.texto(b, "flujo", true),
    p_ejecucion: leer.texto(b, "ejecucion"),
    p_nodo: leer.texto(b, "nodo"),
    p_mensaje: leer.texto(b, "mensaje"),
    p_url: leer.texto(b, "url"),
  }),
  mapear: () => ({ ok: true }),
});
