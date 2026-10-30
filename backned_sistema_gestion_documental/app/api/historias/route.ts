/**
 * GET  /api/historias?estado=&anio=&nivel_id=&programa_id=&q=&pagina=
 *      Historias académicas de un nodo del árbol o de una búsqueda (nombre, cédula o título de un
 *      documento), 20 por página (RF-AC-020). historias.consultar; RA solo activas. fn_historias_listar (migración 28).
 * POST /api/historias  (multipart: archivo, programa_id, estado (graduado|retirado|activa), anio,
 *                       titulo, apellidos, nombres, numero_documento, tipo_documento? = CC)
 * Guarda UN documento en la historia académica de un estudiante (carga D, RF-AC-021).
 * El título (p. ej. "Acta de grado") lo escribe quien carga y sirve para buscarlo en Consulta › Buscar.
 * El nombre y la cédula salen del nombre del archivo (APELLIDOS NOMBRES - cédula.pdf). Si el estudiante
 * ya existe (misma cédula) se usa el suyo; si ya tiene historia en ese programa, el documento se agrega.
 * Mismo archivo en la misma historia → 409 y no se guarda (RN-AC-11). Sin IA (RN-AC-13).
 * Permiso cargas.historias. Función SQL: fn_historia_cargar (migración 25).
 */
import { createHash } from "node:crypto";
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../lib/auth";
import { guardarArchivo } from "../../../lib/archivos";
import { rpc, tienePermiso } from "../../../lib/catalogos";
import { SolicitudInvalida } from "../../../lib/n8n";
import { errorResponse, forbidden, handleError, jsonResponse } from "../../../lib/errors";
import { supabase } from "../../../lib/supabase";

const MIGRACION = "20261025000000_historias_carga_busqueda.sql";
const MIGRACION_LISTA = "20261028000000_historias_transferencias_busqueda.sql";
const EXT_PERMITIDAS = ["pdf", "jpg", "jpeg", "png", "tif", "tiff"];
const MAX_BYTES = 50 * 1024 * 1024;

function texto(form: FormData, campo: string): string | undefined {
  const raw = form.get(campo);
  return typeof raw === "string" && raw.trim() !== "" ? raw.trim() : undefined;
}

export async function GET(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    const sp = request.nextUrl.searchParams;
    const filtros: Record<string, string> = {};
    for (const k of ["estado", "anio", "nivel_id", "programa_id", "q"]) {
      const v = sp.get(k)?.trim();
      if (v) filtros[k] = v;
    }
    if (filtros.estado && !["activa", "retirado", "graduado"].includes(filtros.estado)) {
      throw new SolicitudInvalida("estado debe ser activa, retirado o graduado", "estado", "lista");
    }
    for (const k of ["anio", "nivel_id", "programa_id"]) {
      if (filtros[k] && !/^\d+$/.test(filtros[k])) throw new SolicitudInvalida(`${k} debe ser un número`, k, "formato");
    }
    const pagina = Math.max(1, Number(sp.get("pagina") ?? "1") || 1);
    return jsonResponse(await rpc("fn_historias_listar", {
      p_usuario_id: usuario.id, p_filtros: filtros, p_pagina: pagina, p_limite: 20,
    }, MIGRACION_LISTA));
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}

export async function POST(request: NextRequest) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    // El permiso se revisa antes de guardar el archivo (la función SQL lo vuelve a revisar y audita).
    if (!(await tienePermiso(usuario.id, "cargas.historias"))) {
      return forbidden("No tiene permiso para esta acción: Requiere el permiso cargas.historias");
    }

    const form = await request.formData();
    const archivo = form.get("archivo");
    if (!(archivo instanceof File)) throw new SolicitudInvalida("Campo 'archivo' es obligatorio", "archivo", "obligatorio");
    const ext = archivo.name.split(".").pop()?.toLowerCase() ?? "";
    if (!EXT_PERMITIDAS.includes(ext)) throw new SolicitudInvalida("Formato no permitido. Usa PDF, JPG, PNG o TIFF", "archivo", "formato");
    if (archivo.size === 0) throw new SolicitudInvalida("El archivo está vacío", "archivo", "vacio");
    if (archivo.size > MAX_BYTES) throw new SolicitudInvalida("El archivo supera los 50 MB", "archivo", "tamano");

    const datos = {
      programa_id: texto(form, "programa_id"),
      estado: texto(form, "estado"),
      anio: texto(form, "anio"),
      apellidos: texto(form, "apellidos"),
      nombres: texto(form, "nombres"),
      numero_documento: texto(form, "numero_documento"),
      tipo_documento: texto(form, "tipo_documento"),
      titulo: texto(form, "titulo"),
    };
    if (!datos.titulo) throw new SolicitudInvalida("Escriba el título del documento (p. ej. Acta de grado)", "titulo", "obligatorio");
    if (!datos.apellidos) throw new SolicitudInvalida("Escriba los apellidos del estudiante", "apellidos", "obligatorio");
    if (!datos.nombres) throw new SolicitudInvalida("Escriba los nombres del estudiante", "nombres", "obligatorio");
    if (!datos.numero_documento) throw new SolicitudInvalida("Escriba el documento de identidad", "numero_documento", "obligatorio");
    if (!datos.programa_id) throw new SolicitudInvalida("Elija el programa", "programa_id", "obligatorio");

    const buffer = Buffer.from(await archivo.arrayBuffer());
    const hash = createHash("sha256").update(buffer).digest("hex");

    // Duplicado antes de guardar el archivo: misma huella en la historia de ese estudiante y programa.
    const numero = datos.numero_documento.replace(/[^0-9A-Za-z]/g, "");
    const { data: est } = await supabase.from("estudiante").select("id")
      .eq("tipo_documento", (datos.tipo_documento ?? "CC").toUpperCase()).eq("numero_documento", numero).maybeSingle();
    if (est) {
      const { data: hist } = await supabase.from("historia_academica").select("id")
        .eq("estudiante_id", est.id).eq("programa_id", Number(datos.programa_id)).maybeSingle();
      if (hist) {
        const { data: rep } = await supabase.from("historia_documento").select("id")
          .eq("historia_id", hist.id).eq("hash_sha256", hash).eq("anulado", false).limit(1);
        if (rep && rep.length > 0) {
          return errorResponse("Archivo duplicado", 409, { detalle: "Ese archivo ya está en la historia del estudiante", campo: "archivo", tipo: "duplicado" });
        }
      }
    }

    const guardado = await guardarArchivo(buffer, archivo.name, "historia", { anio: Number(datos.anio) || undefined }, usuario);
    const resultado = await rpc<Record<string, unknown>>("fn_historia_cargar", {
      p_usuario_id: usuario.id,
      p_datos: { ...datos, archivo_id: guardado.archivo_id },
    }, MIGRACION);
    return jsonResponse(resultado, 201);
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse("Datos inválidos", 400, { detalle: err.message, campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}
