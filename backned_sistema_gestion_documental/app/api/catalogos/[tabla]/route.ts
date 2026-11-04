/**
 * GET  /api/catalogos/[tabla]?pagina=&limite=&estado=&buscar=&<filtro>=  → listado paginado
 * POST /api/catalogos/[tabla]                                           → crear (permiso en la base, auditado)
 * Catálogos: dependencias, trd, asuntos, tipos-documentales, programas, ubicaciones, usuarios.
 */
import { NextRequest } from "next/server";
import { obtenerConfig, extraerPayload, listarCatalogo, guardarCatalogo, tienePermiso } from "../../../../lib/catalogos";
import { obtenerUsuarioAutenticado } from "../../../../lib/auth";
import { forbidden, handleError, jsonResponse } from "../../../../lib/errors";
import { parseBody } from "../../../../lib/n8n";

export async function GET(request: NextRequest, { params }: { params: Promise<{ tabla: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const cfg = obtenerConfig((await params).tabla);
    // La lista de usuarios tiene datos personales: solo quien los gestiona.
    if (cfg.slug === "usuarios" && !(await tienePermiso(usuario.id, "usuarios.gestionar"))) {
      return forbidden("No tiene permiso para ver los usuarios");
    }
    const sp = request.nextUrl.searchParams;
    const filtros: Record<string, string> = {};
    for (const c of cfg.filtros) {
      const v = sp.get(c);
      if (v) filtros[c] = v;
    }
    const resultado = await listarCatalogo(cfg, {
      pagina: Number(sp.get("pagina") ?? "1"),
      limite: Number(sp.get("limite") ?? "50"),
      estado: sp.get("estado") ?? undefined,
      buscar: sp.get("buscar") ?? undefined,
      filtros,
    });
    return jsonResponse(resultado);
  } catch (err) {
    return handleError(err);
  }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ tabla: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const cfg = obtenerConfig((await params).tabla);
    const payload = extraerPayload(await parseBody(request), cfg, "crear");
    return jsonResponse(await guardarCatalogo(usuario.id, cfg, null, payload), 201);
  } catch (err) {
    return handleError(err);
  }
}
