/**
 * GET /api/inicio
 * Indicadores del panel de Inicio. Cada uno es null si el perfil no tiene ese permiso: se revisa con
 * tienePermiso (no audita), porque abrir el panel no es un intento de acceder a lo que no se puede ver.
 * El perfil Dependencia solo cuenta lo de su dependencia.
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { tienePermiso } from "../../../lib/catalogos";
import { db } from "../../../lib/db";
import { handleError, jsonResponse } from "../../../lib/errors";

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const soloSuya = usuario.perfil === "dependencia" ? usuario.dependencia_id ?? -1 : null;

    const contar = async (permiso: string, consulta: () => PromiseLike<{ count: number | null; error: unknown }>) => {
      if (!(await tienePermiso(usuario.id, permiso))) return null;
      const { count, error } = await consulta();
      if (error) throw error;
      return count ?? 0;
    };
    const hoy = new Date().toISOString().slice(0, 10);
    const conDependencia = <T extends { eq(columna: string, valor: unknown): T }>(q: T) =>
      soloSuya === null ? q : q.eq("dependencia_id", soloSuya);

    const [porClasificar, transferencias, historias, vencidas] = await Promise.all([
      contar("documentos.clasificar", () =>
        conDependencia(db.from("documento").select("id", { count: "exact" }).eq("estado", "por_clasificar").limit(1))),
      contar("cargas.transferencia", () =>
        conDependencia(db.from("transferencia").select("id", { count: "exact" }).eq("estado", "en_proceso").is("anulado_en", null).limit(1))),
      contar("historias.consultar", () =>
        db.from("historia_academica").select("id", { count: "exact" }).limit(1)),
      contar("comunicaciones.consultar", () =>
        conDependencia(db.from("comunicacion").select("id", { count: "exact" }).in("estado", ["remitida", "devuelta"]).lt("fecha_limite", hoy).limit(1))),
    ]);

    return jsonResponse({ por_clasificar: porClasificar, transferencias_en_proceso: transferencias, historias, comunicaciones_vencidas: vencidas });
  } catch (err) {
    return handleError(err);
  }
}
