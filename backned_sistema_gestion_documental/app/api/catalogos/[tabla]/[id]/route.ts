/**
 * GET   /api/catalogos/[tabla]/[id]                        → detalle
 * PATCH /api/catalogos/[tabla]/[id]  { campos… }           → editar
 * PATCH /api/catalogos/[tabla]/[id]  { estado, motivo }    → activar / inactivar (inactivar exige motivo)
 * No hay DELETE: los catálogos nunca se borran (RN-AC-12), solo se inactivan.
 */
import { NextRequest } from "next/server";
import { obtenerConfig, extraerPayload, obtenerCatalogo, guardarCatalogo, cambiarEstadoCatalogo, tienePermiso } from "../../../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { forbidden, handleError, jsonResponse } from "../../../../../lib/errors";
import { idRuta, leer, parseBody, SolicitudInvalida } from "../../../../../lib/n8n";

type Params = { params: Promise<{ tabla: string; id: string }> };

export async function GET(request: NextRequest, { params }: Params) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const p = await params;
    const cfg = obtenerConfig(p.tabla);
    if (cfg.slug === "usuarios" && !(await tienePermiso(usuario.id, "usuarios.gestionar"))) {
      return forbidden("No tiene permiso para ver los usuarios");
    }
    return jsonResponse(await obtenerCatalogo(cfg, idRuta(p)));
  } catch (err) {
    return handleError(err);
  }
}

export async function PATCH(request: NextRequest, { params }: Params) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const p = await params;
    const cfg = obtenerConfig(p.tabla);
    const id = idRuta(p);
    const body = await parseBody(request);

    if ("estado" in body) {
      const estado = leer.texto(body, "estado", true);
      if (estado !== "activo" && estado !== "inactivo") {
        throw new SolicitudInvalida("estado debe ser activo o inactivo", "estado", "lista");
      }
      return jsonResponse(await cambiarEstadoCatalogo(usuario.id, cfg, id, estado, leer.texto(body, "motivo")));
    }

    const payload = extraerPayload(body, cfg, "actualizar");
    return jsonResponse(await guardarCatalogo(usuario.id, cfg, id, payload));
  } catch (err) {
    return handleError(err);
  }
}
