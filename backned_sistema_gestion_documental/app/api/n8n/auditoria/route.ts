/**
 * POST /api/n8n/auditoria — #14 · F2, F3
 * Registra un evento en la auditoría (p. ej. correo enviado pero no registrado).
 * Función SQL: n8n_auditar. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_auditar",
  parametros: (b) => ({
    p_flujo: leer.texto(b, "flujo", true),
    p_detalle: leer.json(b, "detalle") ?? {},
  }),
});
