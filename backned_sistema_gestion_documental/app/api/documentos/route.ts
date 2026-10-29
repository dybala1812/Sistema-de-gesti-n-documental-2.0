/**
 * GET  /api/documentos?estado=clasificado|por_clasificar&q=&dependencia_id=&limite=
 * POST /api/documentos  (multipart: archivo, dependencia_id, anio, asunto_id?, tipo?, consecutivo?, fecha?, caja?, carpeta?, ubicacion_id?)
 * Va en: app/api/documentos/route.ts
 */
import { NextRequest } from "next/server";

import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { alcanceDocumentos } from "../../../lib/archivo";
import { listarClasificados } from "../../../lib/clasificados";
import { DocumentoDuplicado, crearDocumentoIndividual } from "../../../lib/documentos";
import { SolicitudInvalida } from "../../../lib/n8n";
import { errorResponse, handleError, jsonResponse } from "../../../lib/errors";

function enteroQuery(sp: URLSearchParams, campo: string): number | undefined {
  const raw = sp.get(campo);
  if (raw === null || raw === "") return undefined;
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) throw new SolicitudInvalida(`${campo} debe ser un entero positivo`, campo, "rango");
  return n;
}

function enteroForm(form: FormData, campo: string, obligatorio = false): number | undefined {
  const raw = form.get(campo);
  if (typeof raw !== "string" || raw.trim() === "") {
    if (obligatorio) throw new SolicitudInvalida(`Campo '${campo}' es obligatorio`, campo, "obligatorio");
    return undefined;
  }
  const n = Number(raw);
  if (!Number.isInteger(n) || n <= 0) throw new SolicitudInvalida(`${campo} debe ser un entero positivo`, campo, "rango");
  return n;
}

function textoForm(form: FormData, campo: string): string | undefined {
  const raw = form.get(campo);
  return typeof raw === "string" && raw.trim() !== "" ? raw.trim() : undefined;
}

function respuestaInvalida(err: SolicitudInvalida) {
  return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
}

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const { searchParams } = request.nextUrl;
    const estado = searchParams.get("estado") ?? "clasificado";
    if (estado !== "clasificado" && estado !== "por_clasificar") {
      throw new SolicitudInvalida("estado debe ser clasificado o por_clasificar", "estado", "valor");
    }
    // Permiso por bandeja; Dependencia solo ve lo de su dependencia (RF-AC-013).
    const soloDependencia = await alcanceDocumentos(
      usuario, estado === "por_clasificar" ? "documentos.clasificar" : "documentos.consultar");
    const documentos = await listarClasificados({
      estado,
      q: searchParams.get("q") ?? undefined,
      dependencia_id: soloDependencia ?? enteroQuery(searchParams, "dependencia_id"),
      limite: enteroQuery(searchParams, "limite"),
    });
    return jsonResponse(documentos);
  } catch (err) {
    if (err instanceof SolicitudInvalida) return respuestaInvalida(err);
    return handleError(err);
  }
}

export async function POST(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const form = await request.formData();
    const archivo = form.get("archivo");
    if (!(archivo instanceof File)) throw new SolicitudInvalida("Campo 'archivo' es obligatorio", "archivo", "obligatorio");

    const documento = await crearDocumentoIndividual(
      archivo,
      {
        dependencia_id: enteroForm(form, "dependencia_id", true)!,
        anio: enteroForm(form, "anio", true)!,
        asunto_id: enteroForm(form, "asunto_id"),
        tipo: textoForm(form, "tipo"),
        consecutivo: textoForm(form, "consecutivo"),
        fecha: textoForm(form, "fecha"),
        caja: textoForm(form, "caja"),
        carpeta: textoForm(form, "carpeta"),
        ubicacion_id: enteroForm(form, "ubicacion_id"),
      },
      usuario,
    );
    return jsonResponse(documento, 201);
  } catch (err) {
    if (err instanceof SolicitudInvalida) return respuestaInvalida(err);
    if (err instanceof DocumentoDuplicado) {
      return errorResponse("Archivo duplicado", 409, { detalle: err.message });
    }
    return handleError(err);
  }
}