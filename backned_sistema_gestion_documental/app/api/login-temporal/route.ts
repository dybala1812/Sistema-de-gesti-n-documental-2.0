/**
 * ⚠️ TEMPORAL — BORRAR ANTES DEL DESPLIEGUE (ver ia_contexto/login-temporal.md).
 * GET  /api/login-temporal → perfiles de prueba y dependencias (para el formulario).
 * POST /api/login-temporal { perfil, dependencia_id?, clave } → { token, expira, usuario }.
 * Responde 404 si el login temporal no está activo (producción o SGD_LOGIN_TEMPORAL distinto de true).
 */
import { NextRequest } from "next/server";
import { iniciarSesionTemporal, loginTemporalActivo, opcionesLoginTemporal } from "../../../lib/loginTemporal";
import { errorFormulario, handleError, jsonResponse, notFound } from "../../../lib/errors";

export async function GET() {
  if (!loginTemporalActivo()) return notFound();
  try {
    return jsonResponse(await opcionesLoginTemporal());
  } catch (err) {
    return handleError(err);
  }
}

export async function POST(request: NextRequest) {
  if (!loginTemporalActivo()) return notFound();
  try {
    const cuerpo = await request.json().catch(() => null);
    if (!cuerpo || typeof cuerpo !== "object") return errorFormulario("Cuerpo de la petición no válido", 400);
    const origen = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "local";
    return jsonResponse(await iniciarSesionTemporal(cuerpo, origen));
  } catch (err) {
    return handleError(err);
  }
}
