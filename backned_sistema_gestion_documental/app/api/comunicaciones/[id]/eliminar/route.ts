/**
 * @file app/api/comunicaciones/[id]/eliminar/route.ts
 * @description Eliminación física de una comunicación (SOLO PRUEBAS).
 *
 * ⚠️ Esto rompe RN-AC-06 (sin borrado físico). Solo debe usarse en desarrollo
 * para limpiar datos de prueba. En producción se debe anular, no eliminar.
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado, puedeGestionarComunicaciones } from "../../../../../lib/auth";
import { eliminarComunicacionFisica, obtenerComunicacion } from "../../../../../lib/comunicaciones";
import { SolicitudInvalida, idRuta } from "../../../../../lib/n8n";
import { errorResponse, handleError, jsonResponse, notFound, forbidden } from "../../../../../lib/errors";

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!puedeGestionarComunicaciones(usuario)) {
      return forbidden("Solo Archivo Central puede eliminar comunicaciones");
    }

    const comunicacionId = idRuta(await params);

    const previa = await obtenerComunicacion(comunicacionId);
    if (!previa) return notFound("Comunicación no encontrada");

    await eliminarComunicacionFisica(comunicacionId);

    return jsonResponse({ eliminado: true, consecutivo: previa.consecutivo });
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
