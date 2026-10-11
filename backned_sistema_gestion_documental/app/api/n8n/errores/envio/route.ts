/**
 * POST /api/n8n/errores/envio — #13 · F2, F3, F4
 * Registra un error de envío de correo en las comunicaciones afectadas y en la auditoría.
 * Función SQL: n8n_registrar_error_envio. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_registrar_error_envio",
  parametros: (b) => ({
    p_usuario: leer.entero(b, "usuario", true),
    p_comunicaciones: leer.enteros(b, "comunicaciones", true),
    p_dependencia: leer.entero(b, "dependencia"),
    p_detalle: leer.json(b, "detalle") ?? {},
  }),
});
