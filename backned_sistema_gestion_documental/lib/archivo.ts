/**
 * @file lib/archivo.ts
 * @description Archivo navegable y búsqueda avanzada (RF-AC-013, RF-AC-014, SGD-032).
 * Las funciones SQL de la migración 20 revisan los permisos (documentos.consultar /
 * comunicaciones.consultar), limitan al perfil Dependencia a lo suyo y auditan los intentos denegados.
 */
import { errorDeBase, rpc, tienePermiso } from "./catalogos";
import type { UsuarioSGD } from "./auth";
import { supabase } from "./supabase";
import { interpretarConsecutivo } from "./consecutivoTexto";
import { SolicitudInvalida } from "./n8n";

const MIGRACION = "20261020000000_archivo_busqueda.sql";

export async function arbolArchivo(usuarioId: number) {
  return rpc("fn_archivo_arbol", { p_usuario_id: usuarioId }, MIGRACION);
}

function entero(sp: URLSearchParams, campo: string, min: number, max: number): number | undefined {
  const v = sp.get(campo);
  if (v === null || v === "") return undefined;
  if (!/^\d+$/.test(v)) throw new SolicitudInvalida(`${campo} debe ser un número`, campo, "formato");
  const n = Number(v);
  if (n < min || n > max) throw new SolicitudInvalida(`${campo} debe estar entre ${min} y ${max}`, campo, "rango");
  return n;
}

function texto(sp: URLSearchParams, campo: string): string | undefined {
  const v = sp.get(campo)?.trim();
  if (!v) return undefined;
  if (v.length > 200) throw new SolicitudInvalida(`${campo} es demasiado largo`, campo, "rango");
  return v;
}

/**
 * GET /api/archivo/buscar: año, mes, dependencia_id, tipo, asunto_id, asunto, consecutivo (acepta
 * "385 del 29 de febrero"), persona, trd, texto, alcance (todo | documentos | comunicaciones | historias | transferencias), pagina.
 */
export async function buscarArchivo(usuarioId: number, sp: URLSearchParams) {
  const anioActual = new Date().getFullYear();
  const c = interpretarConsecutivo(texto(sp, "consecutivo"));
  const filtros: Record<string, unknown> = {
    anio: entero(sp, "anio", 1900, anioActual) ?? c.anio,
    mes: entero(sp, "mes", 1, 12) ?? c.mes,
    dia: c.dia,
    dependencia_id: entero(sp, "dependencia_id", 1, Number.MAX_SAFE_INTEGER),
    asunto_id: entero(sp, "asunto_id", 1, Number.MAX_SAFE_INTEGER),
    tipo: texto(sp, "tipo") ?? c.tipo,
    asunto: texto(sp, "asunto"),
    consecutivo: c.consecutivo,
    persona: texto(sp, "persona"),
    trd: texto(sp, "trd"),
    texto: texto(sp, "texto"),
    alcance: texto(sp, "alcance"),
  };
  for (const k of Object.keys(filtros)) if (filtros[k] === undefined) delete filtros[k];
  return rpc("fn_archivo_buscar", {
    p_usuario_id: usuarioId,
    p_filtros: filtros,
    p_pagina: entero(sp, "pagina", 1, 100000) ?? 1,
    p_limite: entero(sp, "limite", 1, 100) ?? 20,
  }, MIGRACION);
}

/**
 * Alcance de las bandejas de documentos (/api/clasificados, /api/documentos): exige el permiso
 * (el intento denegado queda auditado) y devuelve la dependencia a la que se limita un usuario del
 * perfil Dependencia (undefined = ve todas). Si la migración 20 aún no está aplicada, revisa el
 * permiso con fn_tiene_permiso (sin auditar) para no dejar las bandejas sin servicio.
 */
export async function alcanceDocumentos(usuario: UsuarioSGD, funcion: "documentos.consultar" | "documentos.clasificar"): Promise<number | undefined> {
  const { data, error } = await supabase.rpc("fn_alcance_consulta", {
    p_usuario_id: usuario.id, p_funcion: funcion, p_recurso_tipo: "documento", p_recurso_id: null,
  });
  let permitido: boolean;
  if (error?.code === "PGRST202") {
    permitido = await tienePermiso(usuario.id, funcion);
  } else if (error) {
    throw errorDeBase(error, MIGRACION);
  } else {
    const a = (Array.isArray(data) ? data[0] : data) as { permitido?: boolean } | null;
    permitido = a?.permitido === true;
  }
  if (!permitido) {
    throw Object.assign(new Error(`No tiene permiso para esta acción: requiere el permiso ${funcion}`), { status: 403 });
  }
  return usuario.perfil === "dependencia" ? (usuario.dependencia_id ?? -1) : undefined;
}
