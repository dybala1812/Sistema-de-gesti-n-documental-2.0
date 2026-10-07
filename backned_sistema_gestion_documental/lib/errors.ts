/**
 * Helpers comunes para respuestas HTTP y manejo de errores.
 */

export type ApiError = {
  error: string;
  detalle?: string;
  codigo?: string;
};

export function jsonResponse<T>(data: T, status = 200): Response {
  return Response.json(data, { status });
}

export function errorResponse(message: string, status = 400, extra?: Partial<ApiError>): Response {
  return Response.json({ error: message, ...extra }, { status });
}

export function unauthorized(message = "No autorizado"): Response {
  return errorResponse(message, 401);
}

export function forbidden(message = "Acceso denegado"): Response {
  return errorResponse(message, 403);
}

export function notFound(message = "Recurso no encontrado"): Response {
  return errorResponse(message, 404);
}

export function handleError(error: unknown): Response {
  if (error instanceof Response) return error;
  const message = error instanceof Error ? error.message : "Error interno del servidor";
  console.error("[backend error]", error);
  return errorResponse(message, 500);
}
