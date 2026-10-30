/**
 * @file middleware.ts
 * @description Middleware global del backend SGD.
 *
 * Agrega headers CORS a todas las rutas /api/* para permitir que el frontend
 * de NOVA (u otro origen autorizado) consuma la API. También responde a las
 * peticiones OPTIONS (preflight).
 */
import { NextRequest, NextResponse } from "next/server";

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ?? "http://localhost:5173")
  .split(",")
  .map(o => o.trim())
  .filter(Boolean);

function getOrigin(request: NextRequest): string | null {
  return request.headers.get("origin");
}

// Solo en desarrollo: el frontend abierto desde otro equipo de la red local (p. ej. la app móvil
// /movil en el celular), en cualquier puerto de Vite. En producción solo vale ALLOWED_ORIGINS.
const RED_LOCAL = /^https?:\/\/(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(:\d{2,5})?$/;
const ES_DESARROLLO = process.env.NODE_ENV !== "production";

function isAllowed(origin: string | null): boolean {
  if (!origin) return false;
  return ALLOWED_ORIGINS.includes(origin) || (ES_DESARROLLO && RED_LOCAL.test(origin));
}

export function middleware(request: NextRequest) {
  const origin = getOrigin(request);
  const allowedOrigin = isAllowed(origin) ? origin : ALLOWED_ORIGINS[0] ?? "";

  // Responder preflight OPTIONS inmediatamente.
  if (request.method === "OPTIONS") {
    const response = new NextResponse(null, { status: 204 });
    response.headers.set("Access-Control-Allow-Origin", allowedOrigin ?? "*");
    response.headers.set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS");
    response.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    response.headers.set("Access-Control-Allow-Credentials", "true");
    return response;
  }

  const response = NextResponse.next();
  response.headers.set("Access-Control-Allow-Origin", allowedOrigin ?? "*");
  response.headers.set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS");
  response.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  response.headers.set("Access-Control-Allow-Credentials", "true");
  return response;
}

export const config = {
  matcher: "/api/:path*",
};
