import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { listarDependencias } from "../../../lib/comunicaciones";
import { handleError, jsonResponse } from "../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    await obtenerUsuarioAutenticado(request);
    const dependencias = await listarDependencias();
    return jsonResponse(dependencias);
  } catch (err) {
    return handleError(err);
  }
}
