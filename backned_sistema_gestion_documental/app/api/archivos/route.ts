import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, extraerToken } from "../../../lib/auth";
import { guardarArchivo } from "../../../lib/archivos";
import { assertSupabaseConfig } from "../../../lib/supabase";
import { handleError, jsonResponse, errorResponse } from "../../../lib/errors";

function esN8N(request: NextRequest): boolean {
  const token = extraerToken(request);
  return token === process.env.N8N_SERVICE_TOKEN;
}

export async function POST(request: NextRequest) {
  try {
    assertSupabaseConfig();
    let usuario;
    const esServicioN8N = esN8N(request);
    if (!esServicioN8N) {
      usuario = await obtenerUsuarioAutenticado(request);
    }

    const formData = await request.formData();
    const archivo = formData.get("archivo");
    const categoria = String(formData.get("categoria") ?? "");
    const contextoRaw = String(formData.get("contexto") ?? "{}");

    if (!archivo || !(archivo instanceof File)) {
      return errorResponse("Campo 'archivo' es obligatorio", 400);
    }
    if (!categoria) {
      return errorResponse("Campo 'categoria' es obligatorio", 400);
    }

    let contexto: Record<string, unknown> = {};
    try {
      contexto = JSON.parse(contextoRaw);
    } catch {
      return errorResponse("Campo 'contexto' debe ser JSON válido", 400);
    }

    const bytes = await archivo.arrayBuffer();
    const buffer = Buffer.from(bytes);

    const guardado = await guardarArchivo(
      buffer,
      archivo.name,
      categoria,
      contexto,
      usuario
    );

    return jsonResponse(guardado, 201);
  } catch (err) {
    return handleError(err);
  }
}
