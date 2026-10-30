/**
 * @file lib/catalogos.ts
 * @description Catálogos administrables del Archivo Central (RF-AC-001 a 005).
 *
 * Reglas:
 *  - Leer: cualquier usuario autenticado, salvo «usuarios», que exige usuarios.gestionar.
 *  - Escribir: por las funciones SQL de la migración 17, que fijan el usuario que actúa
 *    (queda en la auditoría), revisan su permiso (catalogos.gestionar / usuarios.gestionar)
 *    y auditan los intentos denegados.
 *  - No hay borrado físico: inactivar exige motivo, que queda en la auditoría.
 *  - Los errores incluyen campo y tipo para que el formulario marque el campo.
 */
import { supabase } from "./supabase";
import { SolicitudInvalida } from "./n8n";
import { columnaDuplicada, errorFormulario, errorResponse, errorSistema } from "./errors";

export type SlugCatalogo =
  | "niveles"
  | "dependencias"
  | "trd"
  | "asuntos"
  | "tipos-documentales"
  | "programas"
  | "ubicaciones"
  | "usuarios";

type TipoCampo = "texto" | "entero" | "uuid" | "enum";

interface CampoConfig {
  columna: string;
  tipo: TipoCampo;
  obligatorio?: boolean;
  enumValues?: string[];
  valorPorDefecto?: unknown;
}

interface TablaConfig {
  slug: SlugCatalogo;
  tabla: string;
  campos: CampoConfig[];
  ordenPorDefecto: string;
  /** Columnas y relaciones del listado y del detalle. */
  select: string;
  /** Columnas por las que buscar si viene buscar=... */
  buscarColumnas: string[];
  /** Columnas por las que se puede filtrar con ?columna=valor. */
  filtros: string[];
  /** Si se pueden crear registros (los usuarios llegan desde NOVA). */
  creable: boolean;
  /** Si se puede importar desde Excel (RF-AC-001, 002, 004). */
  importable: boolean;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

const DISPOSICION_FINAL = ["conservacion_total", "eliminacion", "seleccion", "digitalizacion"];
// "posgrado" genérico queda para registros viejos; los nuevos usan especialización, maestría o doctorado (migración 24).
const NIVEL_ACADEMICO = ["pregrado", "posgrado", "especializacion", "maestria", "doctorado"];
const PERFILES = ["archivo_central", "dependencia", "registro_academico", "secretaria_general", "administrador"];

const CONFIGS: Record<SlugCatalogo, TablaConfig> = {
  dependencias: {
    slug: "dependencias",
    tabla: "dependencia",
    ordenPorDefecto: "codigo",
    select: "*",
    buscarColumnas: ["codigo", "nombre", "responsable", "correo_oficial"],
    filtros: [],
    creable: true,
    importable: true,
    campos: [
      { columna: "codigo", tipo: "texto", obligatorio: true },
      { columna: "nombre", tipo: "texto", obligatorio: true },
      { columna: "responsable", tipo: "texto" },
      { columna: "correo_oficial", tipo: "texto", obligatorio: true },
      { columna: "nova_dependency_id", tipo: "uuid" },
    ],
  },
  trd: {
    slug: "trd",
    tabla: "trd",
    ordenPorDefecto: "codigo",
    select: "*, padre:serie_padre_id(id, codigo, nombre)",
    buscarColumnas: ["codigo", "nombre", "descripcion"],
    filtros: ["serie_padre_id", "disposicion_final"],
    creable: true,
    importable: true,
    campos: [
      { columna: "codigo", tipo: "texto", obligatorio: true },
      { columna: "nombre", tipo: "texto", obligatorio: true },
      { columna: "descripcion", tipo: "texto" },
      { columna: "serie_padre_id", tipo: "entero" },
      { columna: "anios_gestion", tipo: "entero", obligatorio: true, valorPorDefecto: 2 },
      { columna: "anios_central", tipo: "entero", obligatorio: true },
      { columna: "disposicion_final", tipo: "enum", obligatorio: true, enumValues: DISPOSICION_FINAL },
    ],
  },
  asuntos: {
    slug: "asuntos",
    tabla: "asunto",
    ordenPorDefecto: "nombre",
    select: "*, dependencia:dependencia_id(id, codigo, nombre), trd:trd_id(id, codigo, nombre)",
    buscarColumnas: ["nombre", "descripcion"],
    filtros: ["dependencia_id", "trd_id"],
    creable: true,
    importable: false,
    campos: [
      { columna: "dependencia_id", tipo: "entero", obligatorio: true },
      { columna: "nombre", tipo: "texto", obligatorio: true },
      { columna: "trd_id", tipo: "entero", obligatorio: true },
      { columna: "descripcion", tipo: "texto" },
    ],
  },
  "tipos-documentales": {
    slug: "tipos-documentales",
    tabla: "tipo_documental",
    ordenPorDefecto: "nombre",
    select: "*",
    buscarColumnas: ["nombre"],
    filtros: [],
    creable: true,
    importable: false,
    campos: [{ columna: "nombre", tipo: "texto", obligatorio: true }],
  },
  programas: {
    slug: "programas",
    tabla: "programa_academico",
    ordenPorDefecto: "nombre",
    select: "*, nivel_ref:nivel_id(id, nombre, tipo)",
    buscarColumnas: ["codigo", "nombre"],
    filtros: ["nivel", "nivel_id"],
    creable: true,
    importable: true,
    // El nivel sale de Catálogos › Niveles (migración 27); "nivel" (texto) sigue sirviendo en la importación.
    campos: [
      { columna: "codigo", tipo: "texto" },
      { columna: "nombre", tipo: "texto", obligatorio: true },
      { columna: "nivel_id", tipo: "entero" },
      { columna: "nivel", tipo: "enum", enumValues: NIVEL_ACADEMICO },
    ],
  },
  niveles: {
    slug: "niveles",
    tabla: "nivel_formacion",
    ordenPorDefecto: "orden",
    select: "*",
    buscarColumnas: ["nombre", "codigo"],
    filtros: ["tipo"],
    creable: true,
    importable: false,
    campos: [
      { columna: "nombre", tipo: "texto", obligatorio: true },
      { columna: "tipo", tipo: "enum", obligatorio: true, enumValues: ["pregrado", "tecnico", "posgrado"] },
      { columna: "orden", tipo: "entero" },
    ],
  },
  ubicaciones: {
    slug: "ubicaciones",
    tabla: "ubicacion_fisica",
    ordenPorDefecto: "carro",
    select: "*",
    buscarColumnas: ["carro", "estante", "bandeja", "descripcion"],
    filtros: [],
    creable: true,
    importable: false,
    // Posición en Archivo Central: Carro → Estante → Bandeja (D-23). Bodega y módulo quedan para registros viejos.
    campos: [
      { columna: "carro", tipo: "texto", obligatorio: true },
      { columna: "estante", tipo: "texto", obligatorio: true },
      { columna: "bandeja", tipo: "texto", obligatorio: true },
      { columna: "descripcion", tipo: "texto" },
    ],
  },
  usuarios: {
    slug: "usuarios",
    tabla: "usuario",
    ordenPorDefecto: "nombre",
    // Sin cédula, teléfono ni los datos crudos de NOVA (Ley 1581: solo lo necesario).
    select: "id, nombre, apellido, email, username, perfil, estado, dependencia_id, ultimo_acceso_en, dependencia:dependencia_id(id, codigo, nombre)",
    buscarColumnas: ["nombre", "apellido", "email", "username"],
    filtros: ["perfil", "dependencia_id"],
    creable: false,
    importable: false,
    campos: [
      { columna: "dependencia_id", tipo: "entero" },
      { columna: "perfil", tipo: "enum", enumValues: PERFILES },
    ],
  },
};

export function obtenerConfig(slug: string): TablaConfig {
  const cfg = CONFIGS[slug as SlugCatalogo];
  if (!cfg) throw new SolicitudInvalida(`Catálogo no soportado: ${slug}`, "tabla", "lista");
  return cfg;
}

// ── Validación de los datos del formulario ───────────────────────────────────

function extraerValor(raw: Record<string, unknown>, campo: CampoConfig, modo: "crear" | "actualizar"): unknown {
  const valorRaw = raw[campo.columna];
  const falta = valorRaw === undefined || valorRaw === null || valorRaw === "";

  if (falta) {
    if (modo === "crear" && campo.obligatorio && campo.valorPorDefecto === undefined) {
      throw new SolicitudInvalida(`${campo.columna} es obligatorio`, campo.columna, "obligatorio");
    }
    if (modo === "actualizar") {
      // En una edición, un campo vaciado se guarda como vacío salvo si es obligatorio.
      if (!(campo.columna in raw)) return undefined;
      if (campo.obligatorio) throw new SolicitudInvalida(`${campo.columna} es obligatorio`, campo.columna, "obligatorio");
      return null;
    }
    return campo.valorPorDefecto ?? null;
  }

  if (campo.tipo === "texto") {
    if (typeof valorRaw !== "string" && typeof valorRaw !== "number") {
      throw new SolicitudInvalida(`${campo.columna} debe ser texto`, campo.columna, "tipo");
    }
    const s = String(valorRaw).trim();
    if (campo.obligatorio && !s) throw new SolicitudInvalida(`${campo.columna} es obligatorio`, campo.columna, "obligatorio");
    if (campo.columna === "correo_oficial" && s && !EMAIL_RE.test(s)) {
      throw new SolicitudInvalida("El correo no tiene un formato válido", campo.columna, "formato");
    }
    return s || null;
  }

  if (campo.tipo === "entero") {
    const n = Number(valorRaw);
    if (!Number.isInteger(n) || n < 0) {
      throw new SolicitudInvalida(`${campo.columna} debe ser un número entero`, campo.columna, "rango");
    }
    return n;
  }

  if (campo.tipo === "uuid") {
    const s = String(valorRaw).trim();
    if (!UUID_RE.test(s)) throw new SolicitudInvalida(`${campo.columna} debe ser un UUID válido`, campo.columna, "formato");
    return s;
  }

  // enum
  const s = String(valorRaw).trim();
  if (!campo.enumValues?.includes(s)) {
    throw new SolicitudInvalida(`${campo.columna} debe ser uno de: ${campo.enumValues?.join(", ")}`, campo.columna, "lista");
  }
  return s;
}

export function extraerPayload(raw: Record<string, unknown>, cfg: TablaConfig, modo: "crear" | "actualizar"): Record<string, unknown> {
  const payload: Record<string, unknown> = {};
  for (const campo of cfg.campos) {
    const v = extraerValor(raw, campo, modo);
    if (v !== undefined) payload[campo.columna] = v;
  }
  if (Object.keys(payload).length === 0) {
    throw new SolicitudInvalida("No se recibieron datos", undefined, "obligatorio");
  }
  return payload;
}

// ── Errores de la base → respuesta HTTP con campo ────────────────────────────

const ETIQUETA = /^\[campo:([^|\]]+)\|tipo:([^|\]]+)\]\s*/;

const MIGRACION_CATALOGOS = "20261017000000_catalogos_parametros_auditoria.sql";

/**
 * Convierte un error de supabase.rpc en una Response lista para devolver.
 * `migracion` es el archivo que crea la función, para el aviso de migración pendiente.
 */
export function errorDeBase(error: { message: string; code?: string; details?: string | null }, migracion = MIGRACION_CATALOGOS): Response {
  const etiqueta = ETIQUETA.exec(error.message);
  if (etiqueta) {
    const tipo = etiqueta[2];
    const status = tipo === "existente" ? 404 : 400;
    return errorResponse(error.message.replace(ETIQUETA, ""), status, { campo: etiqueta[1], tipo, codigo: error.code });
  }
  if (error.code === "23505") {
    // details: Key (codigo)=(100) · Key (lower(correo_oficial))=(…) · Key (dependencia_id, lower(nombre))=(…)
    const columna = columnaDuplicada(error.details);
    const enDependencia = /\(dependencia_id,/.test(error.details ?? "") ? " en esta dependencia" : "";
    const etiqueta: Record<string, string> = { codigo: "código", nombre: "nombre", bodega: "bodega, estante y módulo" };
    const mensaje = columna === "correo_oficial" ? "Ya existe una dependencia con ese correo"
      : columna ? `Ya existe un registro con ese ${etiqueta[columna] ?? columna}${enDependencia}` : "Ya existe un registro con esos datos";
    return errorFormulario(mensaje, 409, { campo: columna, tipo: "duplicado" });
  }
  if (error.code === "23503") return errorResponse("El registro relacionado no existe", 400, { tipo: "existente", codigo: error.code });
  if (error.code === "23514") {
    if (/correo/.test(error.message)) return errorResponse("El correo no tiene un formato válido", 400, { campo: "correo_oficial", tipo: "formato" });
    if (/usuario_dependencia_requiere_dep/.test(error.message)) {
      return errorResponse("El perfil Dependencia exige una dependencia", 400, { campo: "dependencia_id", tipo: "obligatorio" });
    }
    return errorResponse("Un valor está fuera del rango permitido", 400, { tipo: "rango", codigo: error.code });
  }
  if (error.code === "PGRST202") {
    return errorSistema("MIGRACION", 500, {
      detalle: `ejecute database/supabase/migrations/${migracion} en el SQL Editor de Supabase`,
    });
  }
  console.error("[catálogos]", error);
  return errorSistema("BASE_DATOS", 500, { interno: error.message });
}

/** Lanza 403 si la función SQL respondió {denegado: true} (el intento ya quedó auditado). */
function siDenegado(data: unknown): void {
  if (data && typeof data === "object" && (data as { denegado?: boolean }).denegado) {
    throw errorResponse("No tiene permiso para esta acción", 403, { detalle: `Requiere el permiso ${(data as { funcion?: string }).funcion}` });
  }
}

/**
 * Llama una función SQL; los errores y el {denegado} salen como Response con el contrato de errores.
 * También la usa lib/historico.ts (registro histórico).
 */
export async function rpc<T>(funcion: string, params: Record<string, unknown>, migracion = MIGRACION_CATALOGOS): Promise<T> {
  const { data, error } = await supabase.rpc(funcion, params);
  if (error) throw errorDeBase(error, migracion);
  siDenegado(data);
  return data as T;
}

/** ¿El usuario tiene el permiso? (lectura; no audita). */
export async function tienePermiso(usuarioId: number, funcion: string): Promise<boolean> {
  const { data, error } = await supabase.rpc("fn_tiene_permiso", { p_usuario_id: usuarioId, p_funcion: funcion });
  if (error) throw errorDeBase(error);
  return data === true;
}

// ── Lectura ──────────────────────────────────────────────────────────────────

export interface ListarOpciones {
  pagina?: number;
  limite?: number;
  estado?: string;
  buscar?: string;
  filtros?: Record<string, string>;
}

/** Falta una relación o columna de una migración nueva (p. ej. nivel_id antes de la migración 27). */
const faltaRelacion = (e: { message: string; code?: string }) =>
  e.code === "PGRST200" || e.code === "42703" || /relationship|does not exist|schema cache/i.test(e.message);

export async function listarCatalogo(cfg: TablaConfig, opciones: ListarOpciones = {}) {
  try {
    return await listarCon(cfg, cfg.select, opciones);
  } catch (e) {
    // Mientras no se aplique la migración que crea la relación, se lista sin ella (no se rompe la pantalla).
    const err = (e as { __errorBase?: { message: string; code?: string } }).__errorBase;
    if (cfg.select !== "*" && err && faltaRelacion(err)) {
      console.warn(`Catálogo ${cfg.slug}: falta una migración (${err.message}); se lista sin relaciones.`);
      return listarCon(cfg, "*", { ...opciones, filtros: Object.fromEntries(Object.entries(opciones.filtros ?? {}).filter(([k]) => k !== "nivel_id")) });
    }
    throw e;
  }
}

async function listarCon(cfg: TablaConfig, select: string, opciones: ListarOpciones) {
  const pagina = Math.max(1, Number(opciones.pagina) || 1);
  const limite = Math.max(1, Math.min(1000, Number(opciones.limite) || 50));
  const desde = (pagina - 1) * limite;

  let query = supabase.from(cfg.tabla).select(select, { count: "exact" });
  if (opciones.estado === "activo" || opciones.estado === "inactivo") query = query.eq("estado", opciones.estado);
  if (opciones.buscar?.trim()) {
    const termino = opciones.buscar.trim().replace(/[%_,()]/g, " ");
    query = query.or(cfg.buscarColumnas.map((c) => `${c}.ilike.%${termino}%`).join(","));
  }
  for (const [k, v] of Object.entries(opciones.filtros ?? {})) {
    if (v && cfg.filtros.includes(k)) query = query.eq(k, v);
  }
  query = query.order(cfg.ordenPorDefecto, { ascending: true });

  const { data, error, count } = await query.range(desde, desde + limite - 1);
  if (error) throw Object.assign(errorDeBase(error), { __errorBase: error });
  const total = count ?? 0;
  return { datos: data ?? [], total, pagina, limite, totalPaginas: Math.max(1, Math.ceil(total / limite)) };
}

export async function obtenerCatalogo(cfg: TablaConfig, id: number) {
  const { data, error } = await supabase.from(cfg.tabla).select(cfg.select).eq("id", id).maybeSingle();
  if (error) throw errorDeBase(error);
  if (!data) throw errorResponse("Registro no encontrado", 404, { campo: "id", tipo: "existente" });
  return data;
}

// ── Escritura (con usuario, permiso y auditoría en la base) ──────────────────

export async function guardarCatalogo(usuarioId: number, cfg: TablaConfig, id: number | null, payload: Record<string, unknown>) {
  if (id === null && !cfg.creable) {
    throw errorResponse("Los usuarios llegan desde NOVA: aquí solo se asignan perfil y dependencia", 400, { tipo: "no_creable" });
  }
  const fila = await rpc<{ id: number }>("fn_catalogo_guardar", {
    p_usuario_id: usuarioId, p_tabla: cfg.tabla, p_id: id, p_datos: payload,
  });
  return obtenerCatalogo(cfg, fila.id);
}

export async function cambiarEstadoCatalogo(usuarioId: number, cfg: TablaConfig, id: number, estado: "activo" | "inactivo", motivo?: string | null) {
  await rpc("fn_catalogo_estado", {
    p_usuario_id: usuarioId, p_tabla: cfg.tabla, p_id: id, p_estado: estado, p_motivo: motivo ?? null,
  });
  return obtenerCatalogo(cfg, id);
}

// ── Importación desde Excel (vista previa o confirmación) ────────────────────

/** Columnas que acepta cada importación (las referencias van por código). */
const COLUMNAS_IMPORTACION: Partial<Record<SlugCatalogo, string[]>> = {
  dependencias: ["codigo", "nombre", "responsable", "correo_oficial"],
  trd: ["codigo", "nombre", "descripcion", "serie_padre_codigo", "anios_gestion", "anios_central", "disposicion_final"],
  programas: ["codigo", "nombre", "nivel"],
};

export function columnasImportacion(cfg: TablaConfig): string[] {
  const cols = COLUMNAS_IMPORTACION[cfg.slug];
  if (!cfg.importable || !cols) throw new SolicitudInvalida("Este catálogo no se importa desde Excel", "tabla", "lista");
  return cols;
}

export async function importarCatalogo(usuarioId: number, cfg: TablaConfig, filas: unknown, confirmar: boolean) {
  const columnas = columnasImportacion(cfg);
  if (!Array.isArray(filas) || filas.length === 0) throw new SolicitudInvalida("El archivo no tiene filas", "filas", "obligatorio");
  if (filas.length > 2000) throw new SolicitudInvalida("Máximo 2.000 filas por importación", "filas", "rango");
  // Solo se envían las columnas conocidas, como texto o número.
  const limpias = filas.map((f) => {
    const o: Record<string, string | number> = {};
    if (f && typeof f === "object") {
      for (const c of columnas) {
        const v = (f as Record<string, unknown>)[c];
        if (typeof v === "number" || (typeof v === "string" && v.trim() !== "")) o[c] = typeof v === "string" ? v.trim() : v;
      }
    }
    return o;
  });
  return rpc<{ confirmado: boolean; total: number; validas: number; con_error: number; filas: unknown[] }>("fn_catalogo_importar", {
    p_usuario_id: usuarioId, p_tabla: cfg.tabla, p_filas: limpias, p_confirmar: confirmar,
  });
}

// ── Parámetros, plantillas y auditoría (RF-AC-006, RF-AC-023) ────────────────

export async function listarParametros() {
  const { data, error } = await supabase.from("parametro").select("clave, valor, tipo, descripcion, minimo, maximo, actualizado_en").order("clave");
  if (error) throw errorDeBase(error);
  return data ?? [];
}

export async function guardarParametro(usuarioId: number, clave: string, valor: unknown) {
  if (typeof valor !== "string" && typeof valor !== "number" && typeof valor !== "boolean") {
    throw new SolicitudInvalida("El valor es obligatorio", "valor", "obligatorio");
  }
  return rpc("fn_parametro_guardar", { p_usuario_id: usuarioId, p_clave: clave, p_valor: String(valor) });
}

export async function listarPlantillas() {
  const { data, error } = await supabase.from("plantilla_correo").select("codigo, nombre, asunto, cuerpo, cuerpo_original, actualizado_en").order("codigo");
  if (error) throw errorDeBase(error);
  return data ?? [];
}

export async function guardarPlantilla(usuarioId: number, codigo: string, b: Record<string, unknown>) {
  const restablecer = b.restablecer === true;
  return rpc("fn_plantilla_guardar", {
    p_usuario_id: usuarioId,
    p_codigo: codigo,
    p_asunto: restablecer ? null : typeof b.asunto === "string" ? b.asunto : null,
    p_cuerpo: restablecer ? null : typeof b.cuerpo === "string" ? b.cuerpo : null,
    p_restablecer: restablecer,
  });
}

export interface FiltrosAuditoria {
  desde?: string | null;
  hasta?: string | null;
  usuario?: number | null;
  accion?: string | null;
  recurso_tipo?: string | null;
  recurso_id?: string | null;
  resultado?: string | null;
  pagina?: number;
  limite?: number;
}

export async function consultarAuditoria(usuarioId: number, f: FiltrosAuditoria) {
  return rpc("fn_auditoria_consultar", {
    p_usuario_id: usuarioId,
    p_desde: f.desde || null,
    p_hasta: f.hasta || null,
    p_usuario: f.usuario || null,
    p_accion: f.accion || null,
    p_recurso_tipo: f.recurso_tipo || null,
    p_recurso_id: f.recurso_id || null,
    p_resultado: f.resultado || null,
    p_pagina: f.pagina || 1,
    p_limite: f.limite || 50,
  });
}
