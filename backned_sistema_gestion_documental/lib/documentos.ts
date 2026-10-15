/**
 * @file lib/documentos.ts
 * @description Carga A · Documento individual: guarda el archivo, crea el documento y registra la auditoría.
 * Va en: backned_sistema_gestion_documental/lib/documentos.ts
 *
 * Regla del asistente: si vienen asunto, consecutivo y fecha, el documento queda "clasificado";
 * si falta alguno, queda "por_clasificar".
 */
import { createHash } from "node:crypto";
import { supabase } from "./supabase"; // AJUSTA si tu cliente se exporta con otro nombre
import { guardarArchivo } from "./archivos";
import { SolicitudInvalida } from "./n8n";
import { SELECT, aDTO, type ClasificadoDTO, type Fila } from "./clasificados";

/** AJUSTA: categoría que acepta guardarArchivo (la misma que valida api/archivos). */
const CATEGORIA_ARCHIVO = "documento";
/** AJUSTA: valores del enum tipo_comunicacion (los mismos de comunicacion.tipo). */
const TIPO_DB: Record<string, string> = { Entrada: "ENT", Salida: "SAL", Interno: "INT" };

const EXT_PERMITIDAS = ["pdf", "jpg", "jpeg", "png", "tif", "tiff"];
const MAX_BYTES = 50 * 1024 * 1024;

type UsuarioAuth = Parameters<typeof guardarArchivo>[4];
const idDe = (u: unknown): number | null => {
  const id = (u as { id?: unknown } | null | undefined)?.id;
  return typeof id === "number" ? id : null;
};

export class DocumentoDuplicado extends Error {
  constructor(public documentoId: number) {
    super("Este archivo ya fue cargado (duplicado)");
  }
}

export interface DatosNuevoDocumento {
  dependencia_id: number;
  anio: number;
  asunto_id?: number;
  tipo?: string;
  consecutivo?: string;
  /** AAAA-MM-DD */
  fecha?: string;
  caja?: string;
  carpeta?: string;
}

async function auditar(usuarioId: number | null, accion: string, documentoId: number, valores: Record<string, unknown>) {
  const { error } = await supabase.from("auditoria").insert({
    usuario_id: usuarioId, accion, recurso_tipo: "documento", recurso_id: String(documentoId), valores_nuevos: valores,
  });
  if (error) console.error("auditoría (no bloquea la operación):", error);
}

export async function crearDocumentoIndividual(
  archivo: File, datos: DatosNuevoDocumento, usuario: UsuarioAuth,
): Promise<ClasificadoDTO> {
  const ext = archivo.name.split(".").pop()?.toLowerCase() ?? "";
  if (!EXT_PERMITIDAS.includes(ext)) {
    throw new SolicitudInvalida("Formato no permitido. Usa PDF, JPG, PNG o TIFF", "archivo", "formato");
  }
  if (archivo.size === 0) throw new SolicitudInvalida("El archivo está vacío", "archivo", "vacio");
  if (archivo.size > MAX_BYTES) throw new SolicitudInvalida("El archivo supera los 50 MB", "archivo", "tamano");
  if (!Number.isInteger(datos.anio) || datos.anio < 1900 || datos.anio > 2100) {
    throw new SolicitudInvalida("anio debe estar entre 1900 y 2100", "anio", "rango");
  }
  if (datos.fecha && !/^\d{4}-\d{2}-\d{2}$/.test(datos.fecha)) {
    throw new SolicitudInvalida("fecha debe tener formato AAAA-MM-DD", "fecha", "formato");
  }
  if (datos.tipo && !TIPO_DB[datos.tipo]) {
    throw new SolicitudInvalida("tipo debe ser Entrada, Salida o Interno", "tipo", "valor");
  }

  const buffer = Buffer.from(await archivo.arrayBuffer());
  const hash = createHash("sha256").update(buffer).digest("hex");

  // Duplicados: misma huella en un documento que no esté anulado.
  const { data: repetido, error: eRep } = await supabase
    .from("documento").select("id").eq("hash_sha256", hash).is("anulado_en", null).limit(1);
  if (eRep) throw eRep;
  if (repetido && repetido.length > 0) throw new DocumentoDuplicado(repetido[0].id as number);

  const guardado = await guardarArchivo(
    buffer, archivo.name, CATEGORIA_ARCHIVO,
    { origen: "documento_individual", dependencia_id: datos.dependencia_id, anio: datos.anio },
    usuario,
  );
  const g = guardado as unknown as { id?: string; archivo_id?: string; archivo?: { id?: string } };
  const archivoId = g.id ?? g.archivo_id ?? g.archivo?.id;
  if (!archivoId) throw new Error("guardarArchivo no devolvió el id del archivo");

  const uid = idDe(usuario);
  const consecutivo = datos.consecutivo?.trim() || null;
  const completo = !!(datos.asunto_id && consecutivo && datos.fecha);
  const ahora = new Date().toISOString();

  const { data, error } = await supabase
    .from("documento")
    .insert({
      archivo_id: archivoId,
      hash_sha256: hash,
      titulo: archivo.name.replace(/\.[^.]+$/, ""),
      dependencia_id: datos.dependencia_id,
      anio: datos.anio,
      asunto_id: datos.asunto_id ?? null,
      tipo_comunicacion: datos.tipo ? TIPO_DB[datos.tipo] : null,
      consecutivo,
      fecha_documento: datos.fecha ?? null,
      caja: datos.caja?.trim() || null,
      carpeta: datos.carpeta?.trim() || null,
      estado: completo ? "clasificado" : "por_clasificar",
      origen: "documento_individual",
      cargado_por: uid,
      clasificado_por: completo ? uid : null,
      clasificado_en: completo ? ahora : null,
    })
    .select(SELECT)
    .single();
  if (error) throw error;

  const dto = aDTO(data as unknown as Fila);
  await auditar(uid, "documento.cargar", dto.id, { origen: "documento_individual", estado: dto.estado, archivo: archivo.name });
  return dto;
}