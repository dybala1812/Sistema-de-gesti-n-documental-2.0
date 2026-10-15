/**
 * GET /api/clasificados?q=&dependencia_id=&limite=
 * Lista los documentos clasificados (bandeja "Clasificados" del Archivo Central).
 * Va en: app/api/clasificados/route.ts
 */
import { NextRequest } from "next/server";

import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { listarClasificados } from "../../../lib/clasificados";
import { SolicitudInvalida } from "../../../lib/n8n";
import { errorResponse, handleError, jsonResponse } from "../../../lib/errors";

function enteroQuery(searchParams: URLSearchParams, campo: string): number | undefined {
  const raw = searchParams.get(campo);
  if (raw === null || raw === "") return undefined;
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) {
    throw new SolicitudInvalida(`${campo} debe ser un entero positivo`, campo, "rango");
  }
  return n;
}

export async function GET(request: NextRequest) {
  try {
    // Solo exige sesión válida. TODO: restringir por perfil con permiso_perfil cuando se defina la función.
    await obtenerUsuarioAutenticado(request);

    const { searchParams } = request.nextUrl;
    const clasificados = await listarClasificados({
      q: searchParams.get("q") ?? undefined,
      dependencia_id: enteroQuery(searchParams, "dependencia_id"),
      limite: enteroQuery(searchParams, "limite"),
    });
    return jsonResponse(clasificados);
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, {
        detalle: err.message,
        campo: err.campo,
        tipo: err.tipo,
      });
    }
    return handleError(err);
  }
}