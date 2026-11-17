/**
 * POST /api/n8n/correos/acuse — F1
 * Registra en el historial que se envió el acuse de recibo (evento acuse_recibo con su Message-ID).
 * Idempotente por Message-ID. Si el acuse falla, F1 usa /api/n8n/correos/error-acuse.
 * Función SQL: n8n_registrar_acuse (migración 38). Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_acuse",
  parametros: (b) => ({
    p_comunicacion_id: leer.entero(b, "comunicacion_id", true),
    p_message_id: leer.texto(b, "message_id", true),
  }),
  // La función devuelve una sola columna y db.rpc la entrega como [id]: se responde { id } (siempre un objeto).
  mapear: (data) => ({ id: (Array.isArray(data) ? data[0] : data) ?? null }),
});
