import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, extraerToken } from "../../../../lib/auth";
import { obtenerArchivo } from "../../../../lib/archivos";
import { assertSupabaseConfig, supabase } from "../../../../lib/supabase";
import { SolicitudInvalida } from "../../../../lib/n8n";
import { errorResponse, handleError } from "../../../../lib/errors";

function esN8N(request: NextRequest): boolean {
  const token = extraerToken(request);
  return token === process.env.N8N_SERVICE_TOKEN;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * ¿Puede este usuario descargar el archivo? Revisa el recurso dueño (documento, historia, adjunto
 * de comunicación, transferencia, lote) con fn_archivo_puede_descargar (migración 26), que deja el
 * intento denegado en la auditoría. Si la migración aún no está aplicada: en desarrollo se permite
 * con un aviso en consola; en producción se niega (nunca abierto por omisión).
 */
async function puedeDescargar(usuarioId: number, archivoId: string): Promise<boolean> {
  const { data, error } = await supabase.rpc("fn_archivo_puede_descargar", { p_usuario_id: usuarioId, p_archivo_id: archivoId });
  if (!error) return data === true;
  const falta = error.code === "PGRST202" || /fn_archivo_puede_descargar/.test(error.message);
  if (falta && process.env.NODE_ENV !== "production") {
    console.warn("Falta la migración 20261026000000_archivo_permiso_descarga.sql: la descarga no revisa el permiso por recurso.");
    return true;
  }
  console.error("fn_archivo_puede_descargar:", error.message);
  return false;
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    assertSupabaseConfig();
    const n8n = esN8N(request);
    const usuario = n8n ? null : await obtenerUsuarioAutenticado(request);

    const { id } = await params;
    if (!UUID.test(id)) {
      throw new SolicitudInvalida("id debe ser un UUID válido", "id", "formato");
    }
    // Permiso por recurso (n8n, con su token de servicio, descarga los adjuntos que reenvía F5).
    // Mismo 403 exista o no el archivo: no se revela qué ids existen.
    if (usuario && !(await puedeDescargar(usuario.id, id))) {
      return errorResponse("No tiene permiso para ver este archivo", 403);
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
