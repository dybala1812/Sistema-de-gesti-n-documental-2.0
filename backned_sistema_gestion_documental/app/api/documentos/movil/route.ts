/**
 * GET /api/documentos/movil
 * Los últimos 10 documentos cargados desde la app del celular (carga F, RF-AC-022), del más reciente al más
 * antiguo. Solo para confirmar en el celular que la carga llegó: ver, buscar y clasificar se hace en la web.
 * Requiere documentos.consultar; un usuario de Dependencia solo ve los de su dependencia.
 */
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { alcanceDocumentos } from "../../../../lib/archivo";
import { SELECT, aDTO, type Fila } from "../../../../lib/clasificados";
import { supabase } from "../../../../lib/supabase";
import { handleError, jsonResponse } from "../../../../lib/errors";

const ULTIMOS = 10;

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const dependenciaId = await alcanceDocumentos(usuario, "documentos.consultar");

    let consulta = supabase
      .from("documento").select(SELECT)
      .eq("origen", "app_movil").neq("estado", "anulado")
      .order("cargado_en", { ascending: false }).limit(ULTIMOS);
    if (dependenciaId !== undefined) consulta = consulta.eq("dependencia_id", dependenciaId);

    const { data, error } = await consulta;
    if (error) throw error;
    return jsonResponse((data ?? []).map(f => aDTO(f as unknown as Fila)));
  } catch (err) {
    return handleError(err);
  }
}
