/**
 * Gestión de archivos físicos del SGD.
 *
 * Los archivos se guardan localmente en carpetas; la BD guarda un id (uuid)
 * que los referencia junto con su ruta relativa, hash y metadatos (RN-AC-14).
 */
import { createHash, randomUUID } from "crypto";
import { mkdir, readFile, writeFile } from "fs/promises";
import { dirname, extname, join } from "path";
import { supabase } from "./supabase";
import type { UsuarioSGD } from "./auth";

const RAIZ = process.env.RAIZ_ARCHIVOS ?? "./archivos_sgd";

export interface ArchivoSubido {
  archivo_id: string;
  nombre_original: string;
  hash_sha256: string;
  tamano_bytes: number;
  mime: string;
  ruta_relativa: string;
}

function normalizarExtension(nombre: string): string {
  const ext = extname(nombre).toLowerCase().replace(".", "");
  return ext || "bin";
}

function mimeDesdeExtension(ext: string): string {
  const map: Record<string, string> = {
    pdf: "application/pdf",
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    gif: "image/gif",
    webp: "image/webp",
    doc: "application/msword",
    docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    xls: "application/vnd.ms-excel",
    xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    txt: "text/plain",
    zip: "application/zip",
  };
  return map[ext] ?? "application/octet-stream";
}

export async function validarParametrosArchivo(
  tamanoBytes: number,
  extension: string
): Promise<{ ok: true } | { ok: false; error: string; status: number }> {
  const { data: paramTamano } = await supabase.rpc("fn_parametro_entero", {
    p_clave: "tamano_maximo_archivo_mb",
  });
  const maxMb = paramTamano ?? 50;
  if (tamanoBytes > maxMb * 1024 * 1024) {
    return { ok: false, error: `Archivo excede ${maxMb} MB`, status: 413 };
  }

  const { data: paramFormatos } = await supabase
    .from("parametro")
    .select("valor")
    .eq("clave", "formatos_permitidos")
    .single();

  const formatosPorDefecto = ["pdf", "jpg", "jpeg", "png", "doc", "docx", "xls", "xlsx", "txt", "zip"];
  const formatosParam = (paramFormatos?.valor ?? "")
    .toLowerCase()
    .split(",")
    .map((f: string) => f.trim())
    .filter(Boolean);

  const formatos = Array.from(new Set([...formatosPorDefecto, ...formatosParam]));

  if (!formatos.includes(extension)) {
    return { ok: false, error: `Formato .${extension} no permitido. Permitidos: ${formatos.join(", ")}`, status: 415 };
  }

  return { ok: true };
}

export async function guardarArchivo(
  buffer: Buffer,
  nombreOriginal: string,
  categoria: string,
  contexto: Record<string, unknown>,
  usuario?: UsuarioSGD
): Promise<ArchivoSubido> {
  const extension = normalizarExtension(nombreOriginal);
  const validacion = await validarParametrosArchivo(buffer.length, extension);
  if (!validacion.ok) {
    throw Object.assign(new Error(validacion.error), { status: validacion.status });
  }

  const hash = createHash("sha256").update(buffer).digest("hex");
  const id = randomUUID();
  const anio = (contexto.anio as number) ?? new Date().getFullYear();
  const rutaRelativa = `${categoria}/${anio}/${id}.${extension}`;
  const rutaAbsoluta = join(/*turbopackIgnore: true*/ RAIZ, rutaRelativa);

  await mkdir(dirname(rutaAbsoluta), { recursive: true });
  await writeFile(/*turbopackIgnore: true*/ rutaAbsoluta, buffer);

  const { data, error } = await supabase
    .from("archivo")
    .insert({
      id,
      ruta_relativa: rutaRelativa,
      nombre_original: nombreOriginal,
      extension,
      mime: mimeDesdeExtension(extension),
      tamano_bytes: buffer.length,
      hash_sha256: hash,
      subido_por: usuario?.id ?? null,
    })
    .select()
    .single();

  if (error) {
    throw new Error(`Error guardando referencia en BD: ${error.message}`);
  }

  return {
    archivo_id: data.id,
    nombre_original: data.nombre_original,
    hash_sha256: data.hash_sha256,
    tamano_bytes: Number(data.tamano_bytes),
    mime: data.mime,
    ruta_relativa: data.ruta_relativa,
  };
}

export async function obtenerArchivo(archivoId: string): Promise<{
  buffer: Buffer;
  nombre_original: string;
  mime: string;
}> {
  const { data, error } = await supabase
    .from("archivo")
    .select("ruta_relativa, nombre_original, mime")
    .eq("id", archivoId)
    .single();

  if (error || !data) {
    throw Object.assign(new Error("Archivo no encontrado"), { status: 404 });
  }

  const rutaAbsoluta = join(/*turbopackIgnore: true*/ RAIZ, data.ruta_relativa);
  const buffer = await readFile(/*turbopackIgnore: true*/ rutaAbsoluta);

  return {
    buffer,
    nombre_original: data.nombre_original,
    mime: data.mime,
  };
}
