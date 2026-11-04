/**
 * @file lib/historico.ts
 * @description Registro histórico de comunicaciones (RF-AC-019, SGD-044).
 *
 *  - Importar: el frontend lee el Excel, el usuario mapea sus columnas y aquí llegan las filas ya
 *    normalizadas. La función SQL valida cada fila, crea comunicaciones cerradas con consecutivo del
 *    sistema (bloque 900001+) y conserva el número original (RN-AC-10). Es idempotente.
 *  - Consultar: calendario de 12 meses y lista de un mes.
 * Los permisos (cargas.historico para importar, comunicaciones.consultar para ver) se revisan en la
 * base y los intentos denegados quedan en la auditoría.
 */
import { rpc } from "./catalogos";
import { SolicitudInvalida } from "./n8n";

/** Migración que crea las funciones (para el aviso si falta aplicarla). */
const MIGRACION = "20261019000000_historico_comunicaciones.sql";

/** Columnas del sistema a las que se mapea el Excel. */
export const CAMPOS_HISTORICO = [
  "tipo", "numero_original", "fecha", "asunto", "remitente", "destinatario", "dependencia", "observaciones",
] as const;

const MAX_FILAS = 5000;
const MAX_TEXTO = 2000;

/** Deja solo las columnas conocidas, como texto recortado (las celdas vacías no se envían). */
function limpiarFilas(filas: unknown): Record<string, string>[] {
  if (!Array.isArray(filas) || filas.length === 0) {
    throw new SolicitudInvalida("El archivo no tiene filas para importar", "filas", "obligatorio");
  }
  if (filas.length > MAX_FILAS) {
    throw new SolicitudInvalida(`Máximo ${MAX_FILAS.toLocaleString("es-CO")} filas por importación`, "filas", "rango");
  }
  return filas.map((f) => {
    const fila: Record<string, string> = {};
    if (f && typeof f === "object") {
      for (const campo of CAMPOS_HISTORICO) {
        const v = (f as Record<string, unknown>)[campo];
        if (v === null || v === undefined) continue;
        const s = String(v).trim().slice(0, MAX_TEXTO);
        if (s) fila[campo] = s;
      }
    }
    return fila;
  });
}

export async function importarHistorico(usuarioId: number, cuerpo: Record<string, unknown>) {
  const tipoDefecto = typeof cuerpo.tipo === "string" && cuerpo.tipo.trim() ? cuerpo.tipo.trim() : null;
  return rpc("fn_historico_importar", {
    p_usuario_id: usuarioId,
    p_filas: limpiarFilas(cuerpo.filas),
    p_confirmar: cuerpo.confirmar === true,
    p_tipo_defecto: tipoDefecto,
  }, MIGRACION);
}

function entero(valor: string | null, campo: string, min: number, max: number): number {
  if (valor === null || !/^\d+$/.test(valor)) throw new SolicitudInvalida(`${campo} debe ser un número`, campo, "formato");
  const n = Number(valor);
  if (n < min || n > max) throw new SolicitudInvalida(`${campo} debe estar entre ${min} y ${max}`, campo, "rango");
  return n;
}

export async function calendarioHistorico(usuarioId: number, sp: URLSearchParams) {
  return rpc("fn_historico_calendario", {
    p_usuario_id: usuarioId,
    p_anio: entero(sp.get("anio"), "anio", 1990, new Date().getFullYear()),
    p_tipo: sp.get("tipo") || null,
  }, MIGRACION);
}

export async function comunicacionesDelMes(usuarioId: number, sp: URLSearchParams) {
  return rpc("fn_historico_mes", {
    p_usuario_id: usuarioId,
    p_anio: entero(sp.get("anio"), "anio", 1990, new Date().getFullYear()),
    p_mes: entero(sp.get("mes"), "mes", 1, 12),
    p_tipo: sp.get("tipo") || null,
    p_pagina: Number(sp.get("pagina") ?? "1") || 1,
    p_limite: Number(sp.get("limite") ?? "50") || 50,
  }, MIGRACION);
}
