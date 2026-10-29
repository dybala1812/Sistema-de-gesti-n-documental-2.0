/**
 * POST /api/documentos/[id]/anular   { motivo }
 * Anula un documento del archivo (RF-AC-024). No se borra (RN 6): queda en estado "anulado"
 * con motivo, quién y cuándo; la auditoría la registra el trigger de la base.
 * Función SQL: fn_anular_documento_usuario (migración 16). Solo Archivo Central o Administrador.
 */
import { NextRequest } from "next/server";
import { supabase } from "../../../../../lib/supabase";
import { obtenerUsuarioAutenticado, requerirPerfil } from "../../../../../lib/auth";
import { SolicitudInvalida, idRuta, leer, parseBody } from "../../../../../lib/n8n";
import { errorResponse, errorSistema, handleError, jsonResponse } from "../../../../../lib/errors";

const ETIQUETA = /^\[campo:([^|\]]+)\|tipo:([^|\]]+)\]\s*/;

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    requerirPerfil(usuario, ["archivo_central", "administrador"]);

    const documentoId = idRuta(await params);
    const b = await parseBody(request);
    const motivo = leer.texto(b, "motivo", true) as string;

    const { data, error } = await supabase.rpc("fn_anular_documento_usuario", {
      p_usuario_id: usuario.id,
      p_documento_id: documentoId,
      p_motivo: motivo,
    });

    if (error) {
      if (error.code === "PGRST202") {
        return errorSistema("MIGRACION", 500, {
          detalle: "ejecute en el SQL Editor de Supabase database/supabase/migrations/20261016000000_anular_documento.sql",
        });
      }
      const etiqueta = ETIQUETA.exec(error.message);
      const mensaje = error.message.replace(ETIQUETA, "");
      const extra = { codigo: error.code, campo: etiqueta?.[1], tipo: etiqueta?.[2] };
      if (etiqueta?.[2] === "existente") return errorResponse(mensaje, 404, extra);
      // Regla de negocio (p. ej. ya estaba anulado) → conflicto; dato inválido → 400.
      return errorResponse(mensaje, error.code === "22023" ? 400 : 409, extra);
    }

    return jsonResponse({ ok: true, documento: Array.isArray(data) ? data[0] : data });
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}
