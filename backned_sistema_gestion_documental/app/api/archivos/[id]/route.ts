import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, extraerToken } from "../../../../lib/auth";
import { obtenerArchivo } from "../../../../lib/archivos";
import { assertSupabaseConfig } from "../../../../lib/supabase";
import { SolicitudInvalida } from "../../../../lib/n8n";
import { errorResponse, handleError } from "../../../../lib/errors";

function esN8N(request: NextRequest): boolean {
  const token = extraerToken(request);
  return token === process.env.N8N_SERVICE_TOKEN;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
    if (!UUID.test(id)) {
      throw new SolicitudInvalida("id debe ser un UUID válido", "id", "formato");
    }
    const archivo = await obtenerArchivo(id);

    return new Response(new Uint8Array(archivo.buffer), {
      status: 200,
      headers: {
        "Content-Type": archivo.mime,
        // filename*= (RFC 6266/5987) conserva tildes y espacios; filename= es el respaldo ASCII.
        // Sin esto el adjunto que reenvía n8n (F5) llegaba como "Certificado%20de%20notas.pdf".
        "Content-Disposition": `attachment; filename="${archivo.nombre_original
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "")
          .replace(/[^\x20-\x7e]/g, "_")
          .replace(/["\\]/g, "_")}"; filename*=UTF-8''${encodeURIComponent(archivo.nombre_original)}`,
      },
    });
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, {
        detalle: err.message,
        campo: err.campo,
        tipo: err.tipo,
      });
    }
    // El registro existe en la base pero el binario no está en la carpeta de este servidor
    // (p. ej. se subió desde otro equipo). 404 claro y sin exponer la ruta absoluta del disco.
    if ((err as NodeJS.ErrnoException)?.code === "ENOENT") {
      return errorResponse("El archivo no está en el almacenamiento de este servidor", 404, {
        detalle: "Está registrado, pero su copia no se encuentra en la carpeta de archivos (pudo subirse desde otro equipo o haberse movido).",
      });
    }
    return handleError(err);
  }
}
