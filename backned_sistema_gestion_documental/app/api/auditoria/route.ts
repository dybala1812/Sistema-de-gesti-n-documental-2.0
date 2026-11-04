/**
 * GET /api/auditoria?desde=&hasta=&usuario=&accion=&recurso_tipo=&recurso_id=&resultado=&pagina=&limite=
 * Consulta la auditoría (RF-AC-023). Solo quien tiene auditoria.consultar; un intento sin
 * permiso queda registrado como denegado. Función SQL: fn_auditoria_consultar.
 * Fechas en ISO 8601; «hasta» es exclusivo.
 */
import { NextRequest } from "next/server";
import { consultarAuditoria } from "../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { handleError, jsonResponse } from "../../../lib/errors";
import { SolicitudInvalida } from "../../../lib/n8n";

function fecha(sp: URLSearchParams, campo: string): string | null {
  const v = sp.get(campo);
  if (!v) return null;
  if (Number.isNaN(Date.parse(v))) throw new SolicitudInvalida(`${campo} debe ser una fecha`, campo, "formato");
  return v;
}

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const sp = request.nextUrl.searchParams;
    const usuarioFiltro = sp.get("usuario");
    if (usuarioFiltro && !/^\d+$/.test(usuarioFiltro)) throw new SolicitudInvalida("usuario debe ser un número", "usuario", "formato");
    const resultado = sp.get("resultado");
    if (resultado && !["ok", "denegado", "error"].includes(resultado)) {
      throw new SolicitudInvalida("resultado debe ser ok, denegado o error", "resultado", "lista");
    }
    return jsonResponse(await consultarAuditoria(usuario.id, {
      desde: fecha(sp, "desde"),
      hasta: fecha(sp, "hasta"),
      usuario: usuarioFiltro ? Number(usuarioFiltro) : null,
      accion: sp.get("accion"),
      recurso_tipo: sp.get("recurso_tipo"),
      recurso_id: sp.get("recurso_id"),
      resultado,
      pagina: Number(sp.get("pagina") ?? "1") || 1,
      limite: Number(sp.get("limite") ?? "50") || 50,
    }));
  } catch (err) {
    return handleError(err);
  }
}
