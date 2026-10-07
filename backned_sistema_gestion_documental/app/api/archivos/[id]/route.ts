import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, extraerToken } from "../../../../lib/auth";
import { obtenerArchivo } from "../../../../lib/archivos";
import { assertSupabaseConfig } from "../../../../lib/supabase";
import { handleError } from "../../../../lib/errors";

function esN8N(request: NextRequest): boolean {
  const token = extraerToken(request);
  return token === process.env.N8N_SERVICE_TOKEN;
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    assertSupabaseConfig();
    if (!esN8N(request)) {
      await obtenerUsuarioAutenticado(request);
    }

    const { id } = await params;
    const archivo = await obtenerArchivo(id);

    return new Response(new Uint8Array(archivo.buffer), {
      status: 200,
      headers: {
        "Content-Type": archivo.mime,
        "Content-Disposition": `attachment; filename="${encodeURIComponent(archivo.nombre_original)}"`,
      },
    });
  } catch (err) {
    return handleError(err);
  }
}
