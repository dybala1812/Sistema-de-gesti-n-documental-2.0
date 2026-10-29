/**
 * Verifica qué migraciones y datos iniciales están aplicados en el proyecto Supabase real.
 * SOLO LECTURA: lee el catálogo OpenAPI de PostgREST (qué funciones/tablas expone) y
 * cuenta filas de las tablas de configuración. No ejecuta funciones ni modifica nada.
 *
 * Uso (desde la carpeta del backend, que tiene @supabase/supabase-js y .env.local):
 *   cd backned_sistema_gestion_documental
 *   node ../database/scripts/verificar_supabase.mjs
 */
import { readFileSync } from "fs";
import { createRequire } from "module";
import { join } from "path";

const require = createRequire(join(process.cwd(), "package.json"));
const { createClient } = require("@supabase/supabase-js");

const env = Object.fromEntries(
  readFileSync(".env.local", "utf8").split(/\r?\n/)
    .filter(l => /^[A-Z0-9_]+=/.test(l))
    .map(l => [l.split("=")[0], l.slice(l.indexOf("=") + 1).trim().replace(/^"|"$/g, "")]),
);
const URL = env.NEXT_PUBLIC_SUPABASE_URL;
const KEY = env.SUPABASE_SERVICE_ROLE_KEY;
if (!URL || !KEY) { console.error("Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en .env.local"); process.exit(1); }

// Una función o tabla representativa de cada migración.
const MIGRACIONES = [
  ["20261007000100_base.sql",                       ["rpc:fn_usuario_actual", "rpc:fn_normalizar"]],
  ["20261007000200_catalogos_y_usuarios.sql",       ["tabla:dependencia", "tabla:plantilla_correo", "rpc:fn_sincronizar_usuario_nova"]],
  ["20261007000300_archivos_cargas_documentos.sql", ["tabla:archivo", "tabla:documento", "rpc:fn_recalcular_lote"]],
  ["20261007000400_comunicaciones.sql",             ["tabla:comunicacion", "rpc:fn_siguiente_consecutivo", "rpc:fn_remitir_comunicacion", "rpc:fn_responder_remitente"]],
  ["20261007000500_historias_academicas.sql",       ["tabla:historia_academica"]],
  ["20261007000600_auditoria_seguridad_vistas.sql", ["tabla:auditoria", "rpc:fn_auditar", "tabla:v_bandeja_comunicaciones"]],
  ["20261007000700_backend_helpers.sql",            ["rpc:fn_set_usuario_actual", "rpc:fn_remitir_comunicacion_usuario", "rpc:fn_anular_comunicacion_usuario", "rpc:fn_devolver_respuesta_usuario", "rpc:fn_responder_remitente_usuario"]],
  ["20261007000800_n8n_registrar_comunicacion.sql", ["rpc:fn_registrar_comunicacion_n8n"]],
  ["20261007000900_n8n_funciones.sql",              ["rpc:n8n_estado_correo", "rpc:n8n_remitir", "rpc:n8n_responder", "rpc:n8n_registrar_error_envio", "rpc:n8n_resumen_dia"]],
  ["20261010000000_mejorar_feedback_errores_respuesta.sql", ["rpc:fn_responder_remitente", "rpc:n8n_responder"]],
  ["20261011000000_f4_manual_y_correo_adicional.sql", ["rpc:n8n_registrar_correo_adicional", "rpc:fn_responder_directo"]],
  ["20261014000000_correo_enviado.sql",             ["tabla:correo_enviado", "rpc:n8n_registrar_correo_enviado"]],
  ["20261016000000_anular_documento.sql",          ["rpc:fn_anular_documento_usuario"]],
  ["20261017000000_catalogos_parametros_auditoria.sql", ["rpc:fn_catalogo_guardar", "rpc:fn_catalogo_importar", "rpc:fn_parametro_guardar", "rpc:fn_plantilla_guardar", "rpc:fn_auditoria_consultar"]],
  ["20261019000000_historico_comunicaciones.sql",   ["rpc:fn_historico_importar", "rpc:fn_historico_calendario", "rpc:fn_historico_mes"]],
  ["20261020000000_archivo_busqueda.sql",          ["rpc:fn_alcance_consulta", "rpc:fn_archivo_arbol", "rpc:fn_archivo_buscar"]],
  ["20261012000000_docx_formato_permitido.sql",     ["tabla:parametro"]],
];

const res = await fetch(`${URL}/rest/v1/`, { headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, Accept: "application/openapi+json" } });
if (!res.ok) { console.error(`No se pudo leer el catálogo de Supabase: HTTP ${res.status}`); process.exit(1); }
const paths = Object.keys((await res.json()).paths ?? {});
const existe = (obj) => {
  const [tipo, nombre] = obj.split(":");
  return paths.includes(tipo === "rpc" ? `/rpc/${nombre}` : `/${nombre}`);
};

console.log("\n=== Migraciones ===");
const faltan = [];
for (const [archivo, objetos] of MIGRACIONES) {
  const ausentes = objetos.filter(o => !existe(o));
  const estado = ausentes.length === 0 ? "OK      " : ausentes.length === objetos.length ? "FALTA   " : "INCOMPLETA";
  if (ausentes.length) faltan.push(archivo);
  console.log(`${estado}  ${archivo}${ausentes.length ? "   (no existe: " + ausentes.map(a => a.split(":")[1]).join(", ") + ")" : ""}`);
}

console.log("\n=== Datos iniciales (seed.sql) ===");
const sb = createClient(URL, KEY, { auth: { persistSession: false } });
const conteo = async (tabla) => {
  const { count, error } = await sb.from(tabla).select("*", { count: "exact", head: true });
  return error ? `error: ${error.message}` : count;
};
const plantillas = await sb.from("plantilla_correo").select("codigo");
const esperadas = ["acuse_recibo", "remision", "devolucion", "respuesta", "recordatorio", "resumen"];
const tiene = new Set((plantillas.data ?? []).map(p => p.codigo));
console.log(`plantilla_correo : ${plantillas.error ? "error: " + plantillas.error.message : `${tiene.size}/6`}${esperadas.filter(e => !tiene.has(e)).length ? "   faltan: " + esperadas.filter(e => !tiene.has(e)).join(", ") : ""}`);
console.log(`parametro        : ${await conteo("parametro")} (esperado 9)`);
// Migración de solo datos (SGD-090): no deja objetos en el catálogo, se revisa por contenido.
const params = await sb.from("parametro").select("clave, descripcion");
const conCodigos = (params.data ?? []).filter(x => /(RNF|RF|RN)-AC|P-\d+|mockup|tentativo/.test(x.descripcion ?? "")).map(x => x.clave);
console.log(`  descripciones  : ${params.error ? "error: " + params.error.message : conCodigos.length ? `con códigos de requisitos (${conCodigos.join(", ")})` : "en lenguaje de usuario"}`);
if (conCodigos.length) faltan.push("20261018000000_parametros_descripcion_usuario.sql");
console.log(`permiso_perfil   : ${await conteo("permiso_perfil")} (esperado 30)`);
console.log(`tipo_documental  : ${await conteo("tipo_documental")} (esperado ≥ 11)`);
console.log(`dependencia      : ${await conteo("dependencia")}`);

console.log("\n=== Qué hacer ===");
if (faltan.length) console.log(`Ejecutar en el SQL Editor de Supabase, en este orden:\n  ${faltan.map(f => "database/supabase/migrations/" + f).join("\n  ")}`);
if (tiene.size < 6) console.log("Ejecutar database/supabase/seed.sql (es idempotente: se puede correr aunque ya haya datos).");
if (!faltan.length && tiene.size === 6) console.log("Todo aplicado.");
