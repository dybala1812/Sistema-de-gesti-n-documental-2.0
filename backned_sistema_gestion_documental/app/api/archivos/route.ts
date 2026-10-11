import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, extraerToken } from "../../../lib/auth";
import { guardarArchivo } from "../../../lib/archivos";
import { assertSupabaseConfig } from "../../../lib/supabase";
import { SolicitudInvalida } from "../../../lib/n8n";
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
      throw new SolicitudInvalida("Campo 'archivo' es obligatorio", "archivo", "obligatorio");
    }
    if (!categoria) {
      throw new SolicitudInvalida("Campo 'categoria' es obligatorio", "categoria", "obligatorio");
    }

    let contexto: Record<string, unknown> = {};
    try {
      contexto = JSON.parse(contextoRaw);
    } catch {
      throw new SolicitudInvalida("Campo 'contexto' debe ser JSON válido", "contexto", "formato");
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
