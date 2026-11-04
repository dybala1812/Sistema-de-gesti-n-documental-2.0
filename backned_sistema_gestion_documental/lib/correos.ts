/**
 * Correo asociado a un evento del historial de una comunicación (para verlo en pantalla).
 *
 * Fuentes, en orden de preferencia:
 *  1. correo_enviado: copia exacta que registra F5 al enviar (migración 14).
 *  2. Lo que la base ya guardaba antes de esa copia:
 *     - recepción → la propia comunicación de entrada;
 *     - respuesta al remitente → la comunicación de salida (SAL);
 *     - correo adicional / respuesta de la dependencia por correo → detalle del evento;
 *     - remisión / devolución → solo el mensaje escrito por Archivo Central (parcial).
 */
import { supabase } from "./supabase";
import type { AdjuntoCom, Comunicacion, TipoEvento } from "./comunicaciones";

export interface CorreoEvento {
  evento_id: number;
  tipo: TipoEvento | "correo_adicional";
  direccion: "enviado" | "recibido";
  de: string | null;
  para: string | null;
  asunto: string | null;
  cuerpo: string | null;
  fecha: string;
  adjuntos: AdjuntoCom[];
  /** false = solo una parte del correo (p. ej. el mensaje escrito, sin la plantilla). */
  completo: boolean;
  aviso?: string;
}

/** Evento del historial que no tiene un correo que mostrar. */
export class SinCorreo extends Error {}

const REMITENTE_SISTEMA = "Archivo Central";

/** Tipo de evento → código de plantilla con que F5 envió el correo. */
const PLANTILLA_POR_EVENTO: Record<string, string> = {
  acuse_recibo: "acuse_recibo",
  remision: "remision",
  devolucion: "devolucion",
  respuesta_remitente: "respuesta",
  recordatorio: "recordatorio",
  correo_adicional: "adicional",
};

/** Ventana para emparejar un evento con su copia cuando el evento no guardó el Message-ID. */
const VENTANA_MS = 15 * 60 * 1000;

const AVISO_SIN_COPIA =
  "Este correo se envió antes de que el sistema guardara una copia; el texto completo está en el buzón de Gmail de Archivo Central.";

type EventoFila = {
  id: number;
  comunicacion_id: number;
  tipo: string;
  message_id: string | null;
  detalle: Record<string, unknown> | null;
  creado_en: string;
};

type CopiaFila = {
  message_id: string;
  para: string;
  asunto: string;
  cuerpo: string | null;
  archivo_ids: string[] | null;
  enviado_en: string;
};

function texto(v: unknown): string | null {
  return typeof v === "string" && v.trim() !== "" ? v : null;
}

async function adjuntosPorIds(ids: string[]): Promise<AdjuntoCom[]> {
  if (!ids.length) return [];
  const { data, error } = await supabase.from("archivo").select("id, nombre_original, tamano_bytes, mime").in("id", ids);
  if (error) throw new Error(error.message);
  return (data ?? []).map((a) => ({
    archivo_id: String(a.id),
    nombre_original: String(a.nombre_original ?? ""),
    tamano_bytes: Number(a.tamano_bytes ?? 0),
    mime: String(a.mime ?? ""),
  }));
}

/** Adjuntos de una comunicación; `eventoId` null = los del correo original. */
async function adjuntosDe(comunicacionId: number, eventoId: number | null): Promise<AdjuntoCom[]> {
  let q = supabase.from("comunicacion_adjunto").select("archivo_id").eq("comunicacion_id", comunicacionId);
  q = eventoId === null ? q.is("evento_id", null) : q.eq("evento_id", eventoId);
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  return adjuntosPorIds((data ?? []).map((r) => String(r.archivo_id)));
}

const CAMPOS_COPIA = "message_id, para, asunto, cuerpo, archivo_ids, enviado_en";

/** PGRST205 = la tabla correo_enviado aún no existe (migración 14 sin aplicar): se usa lo que ya había. */
function errorCopia(error: { code?: string; message: string }): null {
  if (error.code === "PGRST205") return null;
  throw new Error(error.message);
}

async function copiaPorMessageId(messageId: string | null): Promise<CopiaFila | null> {
  if (!messageId) return null;
  const { data, error } = await supabase.from("correo_enviado").select(CAMPOS_COPIA).eq("message_id", messageId).maybeSingle();
  if (error) return errorCopia(error);
  return (data as CopiaFila | null) ?? null;
}

/** Copia de la misma comunicación y plantilla enviada más cerca de la hora del evento. */
async function copiaCercana(comunicacionId: number, plantilla: string, fechaEvento: string): Promise<CopiaFila | null> {
  const t = Date.parse(fechaEvento);
  const { data, error } = await supabase
    .from("correo_enviado")
    .select(CAMPOS_COPIA)
    .eq("comunicacion_id", comunicacionId)
    .eq("plantilla", plantilla)
    .gte("enviado_en", new Date(t - VENTANA_MS).toISOString())
    .lte("enviado_en", new Date(t + VENTANA_MS).toISOString());
  if (error) return errorCopia(error);
  const filas = (data ?? []) as CopiaFila[];
  filas.sort((a, b) => Math.abs(Date.parse(a.enviado_en) - t) - Math.abs(Date.parse(b.enviado_en) - t));
  return filas[0] ?? null;
}

async function salidaDe(entradaId: number) {
  const { data, error } = await supabase
    .from("comunicacion")
    .select("id, message_id, asunto, cuerpo, destinatario_correo, fecha_recepcion")
    .eq("comunicacion_entrada_id", entradaId)
    .eq("tipo", "SAL")
    .order("id", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function obtenerCorreoDeEvento(com: Comunicacion, eventoId: number): Promise<CorreoEvento> {
  const { data, error } = await supabase
    .from("comunicacion_evento")
    .select("id, comunicacion_id, tipo, message_id, detalle, creado_en")
    .eq("id", eventoId)
    .eq("comunicacion_id", com.id)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new SinCorreo("El evento no existe en esta comunicación");

  const ev = data as EventoFila;
  const d = ev.detalle ?? {};
  const base = { evento_id: ev.id, tipo: ev.tipo as CorreoEvento["tipo"] };

  // ── Correos que recibió Archivo Central ───────────────────────────────────
  if (ev.tipo === "recepcion") {
    return {
      ...base,
      direccion: "recibido",
      de: [com.remitente_nombre, com.remitente_correo && `<${com.remitente_correo}>`].filter(Boolean).join(" ") || null,
      para: REMITENTE_SISTEMA,
      asunto: com.asunto,
      cuerpo: com.cuerpo,
      fecha: com.fecha_recepcion,
      adjuntos: await adjuntosDe(com.id, null),
      completo: true,
    };
  }

  if (ev.tipo === "respuesta_dependencia") {
    if (d.directo === true) {
      throw new SinCorreo("Respuesta directa de Archivo Central: el correo enviado está en el evento «Respuesta al remitente».");
    }
    const adjuntos = await adjuntosDe(com.id, ev.id);
    const cuerpo = texto(d.cuerpo) ?? texto(d.mensaje);
    if (!cuerpo && !adjuntos.length) throw new SinCorreo("La dependencia respondió sin texto ni adjuntos guardados.");
    return {
      ...base,
      direccion: "recibido",
      de: texto(d.de_correo) ?? null,
      para: REMITENTE_SISTEMA,
      asunto: texto(d.asunto),
      cuerpo,
      fecha: texto(d.recibido_en) ?? ev.creado_en,
      adjuntos,
      completo: Boolean(texto(d.cuerpo)),
    };
  }

  // ── Correos que envió el sistema (F5) ─────────────────────────────────────
  const plantilla = PLANTILLA_POR_EVENTO[ev.tipo];
  if (!plantilla) throw new SinCorreo("Este paso del historial no envió ni recibió un correo.");

  const salida = ev.tipo === "respuesta_remitente" ? await salidaDe(com.id) : null;
  const copia =
    (await copiaPorMessageId(ev.message_id)) ??
    (await copiaPorMessageId(salida?.message_id ?? null)) ??
    (await copiaCercana(com.id, plantilla, ev.creado_en));

  if (copia) {
    return {
      ...base,
      direccion: "enviado",
      de: REMITENTE_SISTEMA,
      para: copia.para,
      asunto: copia.asunto,
      cuerpo: copia.cuerpo,
      fecha: copia.enviado_en,
      adjuntos: await adjuntosPorIds(copia.archivo_ids ?? []),
      completo: true,
    };
  }

  // Sin copia: lo que la base ya tenía.
  if (salida) {
    return {
      ...base,
      direccion: "enviado",
      de: REMITENTE_SISTEMA,
      para: salida.destinatario_correo ?? com.remitente_correo,
      asunto: salida.asunto,
      cuerpo: salida.cuerpo,
      fecha: ev.creado_en,
      adjuntos: await adjuntosDe(salida.id, null),
      completo: true,
    };
  }
  if (ev.tipo === "correo_adicional" && (texto(d.cuerpo) || texto(d.asunto))) {
    return {
      ...base,
      direccion: "enviado",
      de: REMITENTE_SISTEMA,
      para: texto(d.destinatario_correo),
      asunto: texto(d.asunto),
      cuerpo: texto(d.cuerpo),
      fecha: ev.creado_en,
      adjuntos: await adjuntosDe(com.id, ev.id),
      completo: true,
    };
  }
  if ((ev.tipo === "remision" || ev.tipo === "devolucion") && texto(d.mensaje)) {
    return {
      ...base,
      direccion: "enviado",
      de: REMITENTE_SISTEMA,
      para: null,
      asunto: null,
      cuerpo: texto(d.mensaje),
      fecha: ev.creado_en,
      adjuntos: [],
      completo: false,
      aviso: "Solo se guardó el mensaje que escribió Archivo Central. " + AVISO_SIN_COPIA,
    };
  }
  throw new SinCorreo(AVISO_SIN_COPIA);
}
