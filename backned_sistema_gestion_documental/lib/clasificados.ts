/**
 * @file lib/clasificados.ts
 * @description Consulta de documentos por estado (bandejas "Clasificados" y "Por clasificar").
 * Va en: backned_sistema_gestion_documental/lib/clasificados.ts (reemplaza el anterior).
 */
import { supabase } from "./supabase"; // AJUSTA si tu cliente se exporta con otro nombre

export interface FiltrosClasificados {
  /** "clasificado" (por defecto) o "por_clasificar". */
  estado?: "clasificado" | "por_clasificar";
  /** Busca en título, consecutivo, remitente, destinatario y caja. */
  q?: string;
  dependencia_id?: number;
  /** Máximo de filas (por defecto 200, tope 500). */
  limite?: number;
}

export type TipoLegible = "Entrada" | "Salida" | "Interno";

export interface ClasificadoDTO {
  id: number;
  /** Ej. "194/2024". */
  consecutivo: string | null;
  anio: number;
  /** AAAA-MM-DD */
  fecha: string | null;
  tipo: TipoLegible | null;
  titulo: string;
  /** Remitente (Entrada) o destinatario (Salida/Interno). */
  contraparte: string | null;
  dependencia: string;
  dependencia_id: number | null;
  asunto: string | null;
  trd: string | null;
  caja: string | null;
  carpeta: string | null;
  origen: string | null;
  estado: string;
  archivo_id: string;
  archivo_nombre: string | null;
  paginas: number | null;
  cargado_en: string | null;
}

type Rel<T> = T | T[] | null | undefined;
const uno = <T>(v: Rel<T>): T | null => (Array.isArray(v) ? (v[0] ?? null) : (v ?? null));

export interface Fila {
  id: number;
  titulo: string | null;
  anio: number;
  consecutivo: string | null;
  fecha_documento: string | null;
  tipo_comunicacion: string | null;
  remitente: string | null;
  destinatario: string | null;
  caja: string | null;
  carpeta: string | null;
  estado: string;
  archivo_id: string;
  cargado_en: string | null;
  dependencia: Rel<{ id: number; nombre: string }>;
  asunto: Rel<{ nombre: string; trd: Rel<{ codigo: string }> }>;
  transferencia: Rel<{ codigo: string }>;
  archivo: Rel<{ paginas: number | null; nombre_original: string }>;
}

export const SELECT = `
  id, titulo, anio, consecutivo, fecha_documento, tipo_comunicacion, remitente, destinatario,
  caja, carpeta, estado, archivo_id, cargado_en,
  dependencia:dependencia_id ( id, nombre ),
  asunto:asunto_id ( nombre, trd:trd_id ( codigo ) ),
  transferencia:transferencia_id ( codigo ),
  archivo:archivo_id ( paginas, nombre_original )
`;

/** Acepta ENT/SAL/INT o entrada/salida/interno, en mayúsculas o minúsculas. */
function tipoLegible(valor: string | null): TipoLegible | null {
  const t = (valor ?? "").trim().toLowerCase();
  if (t.startsWith("ent")) return "Entrada";
  if (t.startsWith("sal")) return "Salida";
  if (t.startsWith("int")) return "Interno";
  return null;
}

export function aDTO(f: Fila): ClasificadoDTO {
  const dep = uno(f.dependencia);
  const asunto = uno(f.asunto);
  const trd = uno(asunto?.trd);
  const transf = uno(f.transferencia);
  const archivo = uno(f.archivo);
  const tipo = tipoLegible(f.tipo_comunicacion);
  const contraparte = tipo === "Entrada" ? (f.remitente ?? f.destinatario) : (f.destinatario ?? f.remitente);
  const consecutivo = f.consecutivo
    ? (f.consecutivo.includes("/") ? f.consecutivo : `${f.consecutivo}/${f.anio}`)
    : null;
  return {
    id: f.id,
    consecutivo,
    anio: f.anio,
    fecha: f.fecha_documento,
    tipo,
    titulo: f.titulo ?? archivo?.nombre_original ?? "(sin título)",
    contraparte: contraparte ?? null,
    dependencia: dep?.nombre ?? "—",
    dependencia_id: dep?.id ?? null,
    asunto: asunto?.nombre ?? null,
    trd: trd?.codigo ?? null,
    caja: f.caja,
    carpeta: f.carpeta,
    origen: transf ? `Transferencia ${transf.codigo}` : null,
    estado: f.estado,
    archivo_id: f.archivo_id,
    archivo_nombre: archivo?.nombre_original ?? null,
    paginas: archivo?.paginas ?? null,
    cargado_en: f.cargado_en ?? null,
  };
}

export async function listarClasificados(filtros: FiltrosClasificados = {}): Promise<ClasificadoDTO[]> {
  const limite = Math.min(Math.max(filtros.limite ?? 200, 1), 500);
  const estado = filtros.estado ?? "clasificado";

  let consulta = supabase
    .from("documento")
    .select(SELECT)
    .eq("estado", estado)
    .is("anulado_en", null);

  consulta = estado === "por_clasificar"
    ? consulta.order("cargado_en", { ascending: false })
    : consulta.order("fecha_documento", { ascending: false, nullsFirst: false });
  consulta = consulta.order("id", { ascending: false }).limit(limite);

  if (filtros.dependencia_id) consulta = consulta.eq("dependencia_id", filtros.dependencia_id);

  // Se quitan los caracteres que rompen la sintaxis de .or() de PostgREST.
  const q = filtros.q?.trim().replace(/[%,()*\\]/g, " ").trim();
  if (q) {
    consulta = consulta.or(
      ["titulo", "consecutivo", "remitente", "destinatario", "caja"].map(c => `${c}.ilike.%${q}%`).join(","),
    );
  }

  const { data, error } = await consulta;
  if (error) throw error;
  return ((data ?? []) as unknown as Fila[]).map(aDTO);
}