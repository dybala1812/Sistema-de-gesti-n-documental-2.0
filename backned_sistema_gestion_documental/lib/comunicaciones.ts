/**
 * Helpers de consulta y mapeo para el módulo Comunicaciones.
 */
import { supabase } from "./supabase";
import type { UsuarioSGD } from "./auth";

export type TipoComunicacion = "ENT" | "SAL" | "INT";
export type EstadoComunicacion =
  | "nueva"
  | "remitida"
  | "respondida_dependencia"
  | "devuelta"
  | "cerrada"
  | "anulada";
export type TipoEvento =
  | "recepcion"
  | "acuse_recibo"
  | "remision"
  | "respuesta_dependencia"
  | "devolucion"
  | "respuesta_remitente"
  | "recordatorio"
  | "marcada_escalar"
  | "asociacion_manual"
  | "anulacion"
  | "nota"
  | "error_envio";

export interface DependenciaCom {
  id: number;
  codigo: string;
  nombre: string;
  correo_oficial: string;
}

export interface AdjuntoCom {
  archivo_id: string;
  nombre_original: string;
  tamano_bytes: number;
  mime: string;
  de_respuesta?: boolean;
}

export interface EventoCom {
  id: number;
  tipo: TipoEvento;
  estado_anterior?: EstadoComunicacion | null;
  estado_nuevo?: EstadoComunicacion | null;
  dependencia?: string | null;
  usuario?: string | null;
  detalle?: string | null;
  creado_en: string;
}

export interface Comunicacion {
  id: number;
  tipo: TipoComunicacion;
  consecutivo: string;
  consecutivo_original?: string | null;
  origen: "correo" | "manual" | "historico";
  estado: EstadoComunicacion;
  remitente_nombre: string | null;
  remitente_correo: string | null;
  destinatario_nombre?: string | null;
  destinatario_correo?: string | null;
  asunto: string;
  cuerpo: string | null;
  fecha_recepcion: string;
  dependencia_id: number | null;
  fecha_limite: string | null;
  comunicacion_entrada_id?: number | null;
  n_recordatorios: number;
  por_escalar: boolean;
  anulado_motivo?: string | null;
  cerrado_en?: string | null;
  adjuntos: AdjuntoCom[];
  eventos: EventoCom[];
}

export interface CorreoSinAsociar {
  id: number;
  message_id: string;
  de_nombre: string | null;
  de_correo: string;
  asunto: string | null;
  cuerpo: string | null;
  recibido_en: string;
  motivo: "sin_etiqueta" | "etiqueta_no_coincide" | "remitente_externo_sin_etiqueta" | "otro";
  posible_comunicacion_id: number | null;
  adjuntos: AdjuntoCom[];
  resuelto: boolean;
  resuelto_como?: "asociado" | "nueva" | null;
  comunicacion_id?: number | null;
}

export type FiltroBandeja = {
  estado?: string;
  anio?: number;
  mes?: number;
  dependencia_id?: number;
  tipo?: string;
  q?: string;
};

export function mapComunicacion(row: Record<string, unknown>): Comunicacion {
  return {
    id: Number(row.id),
    tipo: String(row.tipo) as Comunicacion["tipo"],
    consecutivo: String(row.consecutivo),
    consecutivo_original: (row.consecutivo_original as string) ?? null,
    origen: String(row.origen) as Comunicacion["origen"],
    estado: String(row.estado) as Comunicacion["estado"],
    remitente_nombre: (row.remitente_nombre as string) ?? null,
    remitente_correo: (row.remitente_correo as string) ?? null,
    destinatario_nombre: (row.destinatario_nombre as string) ?? null,
    destinatario_correo: (row.destinatario_correo as string) ?? null,
    asunto: String(row.asunto),
    cuerpo: (row.cuerpo as string) ?? null,
    fecha_recepcion: String(row.fecha_recepcion),
    dependencia_id: (row.dependencia_id as number) ?? null,
    fecha_limite: (row.fecha_limite as string) ?? null,
    comunicacion_entrada_id: (row.comunicacion_entrada_id as number) ?? null,
    n_recordatorios: Number(row.n_recordatorios ?? 0),
    por_escalar: Boolean(row.por_escalar),
    anulado_motivo: (row.anulado_motivo as string) ?? null,
    cerrado_en: (row.cerrado_en as string) ?? null,
    adjuntos: (row.adjuntos as AdjuntoCom[]) ?? [],
    eventos: (row.eventos as EventoCom[]) ?? [],
  };
}

export async function listarComunicaciones(
  usuario: UsuarioSGD,
  filtros: FiltroBandeja
): Promise<Comunicacion[]> {
  let query = supabase
    .from("comunicacion")
    .select(
      `
      id, tipo, anio, numero, consecutivo, consecutivo_original, origen, estado,
      message_id, in_reply_to, remitente_nombre, remitente_correo,
      destinatario_nombre, destinatario_correo, asunto, cuerpo, fecha_recepcion,
      dependencia_id, fecha_limite, comunicacion_entrada_id, estudiante_id,
      n_recordatorios, ultimo_recordatorio_en, por_escalar, cerrado_en, anulado_motivo,
      dependencia:dependencia_id (id, nombre),
      adjuntos:comunicacion_adjunto (
        archivo:archivo_id (id, nombre_original, tamano_bytes, mime)
      ),
      eventos:comunicacion_evento (
        id, tipo, estado_anterior, estado_nuevo, message_id, detalle, creado_en,
        dependencia:dependencia_id (nombre),
        usuario:usuario_id (nombre, apellido)
      )
    `
    )
    .order("fecha_recepcion", { ascending: false });

  if (usuario.perfil === "dependencia" && usuario.dependencia_id) {
    query = query.eq("dependencia_id", usuario.dependencia_id);
  }

  if (filtros.estado) {
    query = query.eq("estado", filtros.estado);
  }
  if (filtros.tipo) {
    query = query.eq("tipo", filtros.tipo);
  }
  if (filtros.anio) {
    query = query.eq("anio", filtros.anio);
  }
  if (filtros.dependencia_id) {
    query = query.eq("dependencia_id", filtros.dependencia_id);
  }
  if (filtros.q) {
    const normalizado = filtros.q.trim();
    query = query.or(
      `consecutivo.ilike.%${normalizado}%,asunto.ilike.%${normalizado}%,remitente_nombre.ilike.%${normalizado}%`
    );
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  return (data ?? []).map(mapComunicacion);
}

export async function obtenerComunicacion(id: number): Promise<Comunicacion | null> {
  const { data, error } = await supabase
    .from("comunicacion")
    .select(
      `
      id, tipo, anio, numero, consecutivo, consecutivo_original, origen, estado,
      message_id, in_reply_to, remitente_nombre, remitente_correo,
      destinatario_nombre, destinatario_correo, asunto, cuerpo, fecha_recepcion,
      dependencia_id, fecha_limite, comunicacion_entrada_id, estudiante_id,
      n_recordatorios, ultimo_recordatorio_en, por_escalar, cerrado_en, anulado_motivo,
      adjuntos:comunicacion_adjunto (
        archivo:archivo_id (id, nombre_original, tamano_bytes, mime)
      ),
      eventos:comunicacion_evento (
        id, tipo, estado_anterior, estado_nuevo, message_id, detalle, creado_en,
        dependencia:dependencia_id (nombre),
        usuario:usuario_id (nombre, apellido)
      )
    `
    )
    .eq("id", id)
    .single();

  if (error) return null;
  return mapComunicacion(data as Record<string, unknown>);
}

export async function listarCorreosSinAsociar(): Promise<CorreoSinAsociar[]> {
  const { data, error } = await supabase
    .from("correo_sin_asociar")
    .select(
      `
      id, message_id, in_reply_to, de_nombre, de_correo, asunto, cuerpo, recibido_en,
      motivo, posible_comunicacion_id, adjuntos, resuelto, resuelto_como, comunicacion_id,
      posible:posible_comunicacion_id (consecutivo)
    `
    )
    .eq("resuelto", false)
    .order("recibido_en", { ascending: false });

  if (error) throw new Error(error.message);

  return (data ?? []).map((row: Record<string, unknown>) => ({
    id: Number(row.id),
    message_id: String(row.message_id),
    de_nombre: (row.de_nombre as string) ?? null,
    de_correo: String(row.de_correo),
    asunto: (row.asunto as string) ?? null,
    cuerpo: (row.cuerpo as string) ?? null,
    recibido_en: String(row.recibido_en),
    motivo: String(row.motivo) as CorreoSinAsociar["motivo"],
    posible_comunicacion_id: (row.posible_comunicacion_id as number) ?? null,
    adjuntos: ((row.adjuntos as string[]) ?? []).map((archivoId) => ({
      archivo_id: archivoId,
      nombre_original: "",
      tamano_bytes: 0,
      mime: "",
    })),
    resuelto: Boolean(row.resuelto),
    resuelto_como: (row.resuelto_como as CorreoSinAsociar["resuelto_como"]) ?? null,
    comunicacion_id: (row.comunicacion_id as number) ?? null,
  }));
}

export async function listarDependencias(): Promise<DependenciaCom[]> {
  const { data, error } = await supabase
    .from("dependencia")
    .select("id, codigo, nombre, correo_oficial")
    .eq("estado", "activo")
    .order("nombre");

  if (error) throw new Error(error.message);

  return (data ?? []).map((row: Record<string, unknown>) => ({
    id: Number(row.id),
    codigo: String(row.codigo),
    nombre: String(row.nombre),
    correo_oficial: String(row.correo_oficial),
  }));
}
