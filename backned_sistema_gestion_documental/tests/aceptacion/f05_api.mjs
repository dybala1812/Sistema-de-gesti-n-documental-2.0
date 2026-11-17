/**
 * F-05: casos de aceptación que se pueden verificar por API, con los cinco perfiles y datos ficticios.
 * Levanta una NOVA simulada (un perfil por token) y prueba un backend ya corriendo. No forma parte de
 * `npm test` porque necesita el sistema levantado y ESCRIBE datos: úsela solo con una base desechable.
 * La guía para correrla está en tests/aceptacion/correr_f05.sh.
 *
 * Variables: BACKEND, N8N_SERVICE_TOKEN, NOVA_PUERTO, SQL_CMD (comando psql que recibe el SQL como último
 * argumento, solo para preparar datos), SALIDA (archivo .json con los resultados), RENDIMIENTO=1 (50.000 documentos).
 */
import { createServer } from "node:http";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { performance } from "node:perf_hooks";

const BACKEND = process.env.BACKEND ?? "http://127.0.0.1:3000";
const API = `${BACKEND}/api`;
const TOKEN_N8N = process.env.N8N_SERVICE_TOKEN;
const NOVA_PUERTO = Number(process.env.NOVA_PUERTO ?? 8010);
const SQL_CMD = (process.env.SQL_CMD ?? "").split(" ").filter(Boolean);
const ANIO = new Date().getFullYear();
const SUFIJO = Date.now().toString().slice(-7);

if (!TOKEN_N8N || !SQL_CMD.length) {
  console.error("Faltan N8N_SERVICE_TOKEN o SQL_CMD");
  process.exit(1);
}

// ── NOVA simulada: cada token es un usuario ficticio ─────────────────────────
const PERFILES = {
  "t-adm": { id: "a0000000-0000-4000-8000-000000000001", email: "adm@ejemplo.test", nombre: "Ana", apellido: "Administradora" },
  "t-ac": { id: "a0000000-0000-4000-8000-000000000002", email: "ac@ejemplo.test", nombre: "Alba", apellido: "Central" },
  "t-dep": { id: "a0000000-0000-4000-8000-000000000003", email: "dep@ejemplo.test", nombre: "Dario", apellido: "Dependencia" },
  "t-ra": { id: "a0000000-0000-4000-8000-000000000004", email: "ra@ejemplo.test", nombre: "Rosa", apellido: "Registro" },
  "t-sg": { id: "a0000000-0000-4000-8000-000000000005", email: "sg@ejemplo.test", nombre: "Saul", apellido: "Secretaria" },
};
const nova = createServer((req, res) => {
  const token = (req.headers.authorization ?? "").replace("Bearer ", "");
  const p = PERFILES[token];
  res.setHeader("Content-Type", "application/json");
  if (req.url !== "/api/users/perfil/" || !p) {
    res.writeHead(401);
    return res.end('{"detail":"token no válido"}');
  }
  res.writeHead(200);
  res.end(JSON.stringify({ ...p, username: p.email, roles: [], is_staff: false, activo: true, perfil_tipo: "admin_area" }));
});
await new Promise((ok) => nova.listen(NOVA_PUERTO, "0.0.0.0", ok));

// ── Utilidades ───────────────────────────────────────────────────────────────
const sql = (consulta) => execFileSync(SQL_CMD[0], [...SQL_CMD.slice(1), consulta], { encoding: "utf8" }).trim();

async function llamar(token, metodo, ruta, cuerpo, cabeceras = {}) {
  const esForm = cuerpo instanceof FormData;
  const peticion = () => fetch(`${API}${ruta}`, {
    method: metodo,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(cuerpo && !esForm ? { "Content-Type": "application/json" } : {}),
      ...cabeceras,
    },
    body: esForm ? cuerpo : cuerpo ? JSON.stringify(cuerpo) : undefined,
  });
  // Un reintento: tras una pausa larga (el INSERT de rendimiento) fetch puede reusar un socket ya cerrado.
  const res = await peticion().catch(peticion);
  const texto = await res.text();
  let json = null;
  try { json = JSON.parse(texto); } catch { /* binario o vacío */ }
  return { status: res.status, json, texto, headers: res.headers };
}
const adm = (...a) => llamar("t-adm", ...a);
const ac = (...a) => llamar("t-ac", ...a);
const dep = (...a) => llamar("t-dep", ...a);
const ra = (...a) => llamar("t-ra", ...a);
const sg = (...a) => llamar("t-sg", ...a);
const n8n = (ruta, cuerpo) => llamar(TOKEN_N8N, "POST", `/n8n/${ruta}`, cuerpo ?? {});

function exigir(cond, mensaje) {
  if (!cond) throw new Error(mensaje);
}
function esperar(r, status, que) {
  if (r.status !== status) throw new Error(`${que}: se esperaba ${status} y llegó ${r.status} ${r.texto.slice(0, 160)}`);
  return r.json;
}

const resultados = [];
async function caso(id, requisito, descripcion, fn) {
  try {
    const evidencia = await fn();
    resultados.push({ id, requisito, descripcion, resultado: "OK", evidencia: evidencia ?? "" });
    console.log(`OK     ${id}  ${descripcion}`);
  } catch (e) {
    resultados.push({ id, requisito, descripcion, resultado: "Falló", evidencia: e.message });
    console.log(`FALLÓ  ${id}  ${descripcion}\n         ${e.message}`);
  }
}
const pendiente = (id, requisito, descripcion, motivo) => {
  resultados.push({ id, requisito, descripcion, resultado: "Revisión humana", evidencia: motivo });
  console.log(`HUMANO ${id}  ${descripcion}`);
};

function pdf(texto) {
  return new Blob([`%PDF-1.4\n% ${texto}\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n`], { type: "application/pdf" });
}
function formDocumento(dependencia, anio, texto, extra = {}) {
  const f = new FormData();
  f.set("archivo", pdf(texto), `${texto}.pdf`);
  f.set("dependencia_id", String(dependencia));
  f.set("anio", String(anio));
  for (const [k, v] of Object.entries(extra)) f.set(k, String(v));
  return f;
}

// ── Preparación: usuarios, perfiles y catálogo de prueba ─────────────────────
for (const t of Object.keys(PERFILES)) await llamar(t, "GET", "/catalogos/dependencias");
sql("update usuario set perfil = 'administrador' where email = 'adm@ejemplo.test'");
const usuarios = esperar(await adm("GET", "/catalogos/usuarios?limite=100"), 200, "usuarios").datos;
const idUsuario = (email) => usuarios.find((u) => u.email === email)?.id;
const deps = esperar(await adm("GET", "/catalogos/dependencias?limite=100"), 200, "dependencias").datos;
const depA = deps.find((d) => d.codigo === "150") ?? deps[0];
const depB = deps.find((d) => d.codigo === "170") ?? deps[1];
esperar(await adm("PATCH", `/catalogos/usuarios/${idUsuario("ac@ejemplo.test")}`, { perfil: "archivo_central" }), 200, "perfil AC");
esperar(await adm("PATCH", `/catalogos/usuarios/${idUsuario("dep@ejemplo.test")}`, { perfil: "dependencia", dependencia_id: depA.id }), 200, "perfil Dep");
esperar(await adm("PATCH", `/catalogos/usuarios/${idUsuario("ra@ejemplo.test")}`, { perfil: "registro_academico" }), 200, "perfil RA");
esperar(await adm("PATCH", `/catalogos/usuarios/${idUsuario("sg@ejemplo.test")}`, { perfil: "secretaria_general" }), 200, "perfil SG");
const trd = esperar(await adm("POST", "/catalogos/trd", { codigo: `T${SUFIJO}`, nombre: "Serie de prueba", anios_gestion: 2, anios_central: 8, disposicion_final: "conservacion_total" }), 201, "trd");
const asuntoA = esperar(await adm("POST", "/catalogos/asuntos", { dependencia_id: depA.id, nombre: `Asunto F05 ${SUFIJO}`, trd_id: trd.id }), 201, "asunto");

// ── A. Catálogos ─────────────────────────────────────────────────────────────
await caso("TEST-CAT-01", "RF-AC-001", "Listar, buscar y filtrar dependencias", async () => {
  const l = esperar(await ac("GET", "/catalogos/dependencias"), 200, "lista");
  exigir(l.datos[0].codigo && l.datos[0].nombre && l.datos[0].correo_oficial, "faltan campos");
  const b = esperar(await ac("GET", `/catalogos/dependencias?buscar=${encodeURIComponent(depA.nombre.slice(0, 5))}`), 200, "buscar");
  exigir(b.datos.some((d) => d.id === depA.id), "la búsqueda no encuentra");
  return `${l.total} dependencias`;
});
const correoDep = `pf05${SUFIJO}@ejemplo.test`;
let depNueva;
await caso("TEST-CAT-02", "RF-AC-001", "Crear una dependencia a mano", async () => {
  depNueva = esperar(await adm("POST", "/catalogos/dependencias", { codigo: `P${SUFIJO}`, nombre: `Prueba ${SUFIJO}`, correo_oficial: correoDep }), 201, "crear");
  return `id ${depNueva.id}`;
});
await caso("TEST-CAT-03", "RF-AC-001", "Código o correo repetido se rechaza con el campo", async () => {
  const a = esperar(await adm("POST", "/catalogos/dependencias", { codigo: `P${SUFIJO}`, nombre: "Otra", correo_oficial: `o${SUFIJO}@ejemplo.test` }), 409, "código");
  exigir(a.campo === "codigo", `campo ${a.campo}`);
  const b = esperar(await adm("POST", "/catalogos/dependencias", { codigo: `Q${SUFIJO}`, nombre: "Otra", correo_oficial: correoDep }), 409, "correo");
  exigir(b.campo === "correo_oficial", `campo ${b.campo}`);
  return "409 con campo código y correo_oficial";
});
await caso("TEST-CAT-04", "RF-AC-001", "Inactivar exige motivo y no borra", async () => {
  esperar(await adm("PATCH", `/catalogos/dependencias/${depNueva.id}`, { estado: "inactivo" }), 400, "sin motivo");
  esperar(await adm("PATCH", `/catalogos/dependencias/${depNueva.id}`, { estado: "inactivo", motivo: "Prueba" }), 200, "con motivo");
  const i = esperar(await adm("GET", "/catalogos/dependencias?estado=inactivo&limite=100"), 200, "inactivas");
  exigir(i.datos.some((d) => d.id === depNueva.id), "no aparece en inactivas");
  return "sigue consultable como inactiva";
});
await caso("TEST-CAT-05", "RF-AC-002", "Importar TRD: vista previa y solo entran las válidas", async () => {
  const filas = [
    { codigo: `I${SUFIJO}`, nombre: "Válida", anios_gestion: 2, anios_central: 5, disposicion_final: "eliminacion" },
    { codigo: `T${SUFIJO}`, nombre: "Repetida", anios_gestion: 2, anios_central: 5, disposicion_final: "eliminacion" },
  ];
  const p = esperar(await adm("POST", "/catalogos/trd/importar", { filas, confirmar: false }), 200, "vista previa");
  exigir(p.validas === 1 && p.con_error === 1, `validas ${p.validas} errores ${p.con_error}`);
  const c = esperar(await adm("POST", "/catalogos/trd/importar", { filas, confirmar: true }), 200, "confirmar");
  exigir(c.confirmado && c.validas === 1, "no confirmó");
  return "1 válida, 1 con error";
});
await caso("TEST-CAT-06", "RF-AC-003", "Mismo asunto en dos dependencias sí; en la misma no", async () => {
  const nombre = `Repetible ${SUFIJO}`;
  esperar(await adm("POST", "/catalogos/asuntos", { dependencia_id: depA.id, nombre, trd_id: trd.id }), 201, "primera");
  esperar(await adm("POST", "/catalogos/asuntos", { dependencia_id: depB.id, nombre, trd_id: trd.id }), 201, "otra dependencia");
  esperar(await adm("POST", "/catalogos/asuntos", { dependencia_id: depA.id, nombre, trd_id: trd.id }), 409, "misma dependencia");
});
await caso("TEST-CAT-07", "RF-AC-004", "Tipos, programas y ubicaciones sin borrado", async () => {
  const t = esperar(await adm("POST", "/catalogos/tipos-documentales", { nombre: `Tipo ${SUFIJO}` }), 201, "tipo");
  esperar(await adm("POST", "/catalogos/tipos-documentales", { nombre: `Tipo ${SUFIJO}` }), 409, "repetido");
  esperar(await adm("PATCH", `/catalogos/tipos-documentales/${t.id}`, { nombre: `Tipo editado ${SUFIJO}` }), 200, "editar");
  esperar(await adm("PATCH", `/catalogos/tipos-documentales/${t.id}`, { estado: "inactivo", motivo: "Prueba" }), 200, "inactivar");
  esperar(await adm("POST", "/catalogos/programas", { codigo: `P${SUFIJO}`, nombre: `Programa ${SUFIJO}`, nivel: "pregrado" }), 201, "programa");
  esperar(await adm("POST", "/catalogos/ubicaciones", { carro: "C1", estante: `E${SUFIJO}`, bandeja: "B1" }), 201, "ubicación");
});
await caso("TEST-CAT-08", "RF-AC-005", "Usuarios sin cédula ni teléfono; Archivo Central no los ve", async () => {
  const u = esperar(await adm("GET", "/catalogos/usuarios"), 200, "usuarios").datos[0];
  exigir(!("cedula" in u) && !("telefono" in u), "expone datos personales");
  esperar(await ac("GET", "/catalogos/usuarios"), 403, "Archivo Central");
});
await caso("TEST-CAT-09", "RF-AC-006", "Parámetro dentro y fuera de rango; textos sin códigos", async () => {
  const p = esperar(await adm("GET", "/parametros"), 200, "parámetros");
  exigir(!p.some((x) => /\b(RF|RN|RNF)-/.test(x.descripcion ?? "")), "hay códigos en las descripciones");
  esperar(await adm("PATCH", "/parametros/plazo_respuesta_dias_habiles", { valor: 10 }), 200, "dentro");
  const f = esperar(await adm("PATCH", "/parametros/plazo_respuesta_dias_habiles", { valor: 999 }), 400, "fuera");
  return `fuera de rango: ${f.error}`;
});
await caso("TEST-CAT-10", "RF-AC-006", "Plantilla: guardar y restablecer (API)", async () => {
  const antes = esperar(await adm("GET", "/plantillas"), 200, "plantillas").find((p) => p.codigo === "acuse_recibo");
  esperar(await adm("PATCH", "/plantillas/acuse_recibo", { asunto: `${antes.asunto} (prueba)`, cuerpo: antes.cuerpo }), 200, "guardar");
  esperar(await adm("PATCH", "/plantillas/acuse_recibo", { restablecer: true }), 200, "restablecer");
  const luego = esperar(await adm("GET", "/plantillas"), 200, "plantillas").find((p) => p.codigo === "acuse_recibo");
  exigir(luego.cuerpo === luego.cuerpo_original, "no restableció");
});

// ── B. Auditoría, permisos y anulación ───────────────────────────────────────
await caso("TEST-AUD-01", "RF-AC-023", "Auditoría filtra y no se puede borrar", async () => {
  const a = esperar(await adm("GET", "/auditoria?recurso_tipo=dependencia&limite=5"), 200, "auditoría");
  exigir(a.datos.length > 0 && a.datos.every((f) => f.recurso_tipo === "dependencia"), "filtro");
  const d = await adm("DELETE", "/auditoria");
  exigir(d.status === 405, `DELETE respondió ${d.status}`);
  exigir(sql("select count(*) from pg_trigger where tgrelid = 'auditoria'::regclass and not tgisinternal") !== "0", "sin trigger");
  return "DELETE 405";
});
await caso("TEST-AUD-02", "RF-AC-023", "Intentos sin permiso se niegan y quedan auditados", async () => {
  esperar(await ac("PATCH", "/parametros/plazo_respuesta_dias_habiles", { valor: 11 }), 403, "AC parámetros");
  esperar(await dep("POST", "/catalogos/tipos-documentales", { nombre: `Negado ${SUFIJO}` }), 403, "Dep catálogo");
  const a = esperar(await adm("GET", "/auditoria?resultado=denegado&limite=20"), 200, "denegados");
  exigir(a.datos.length >= 2, "no aparecen");
  esperar(await ac("GET", "/auditoria?limite=1"), 200, "D-28: Archivo Central consulta");
  return `${a.total ?? a.datos.length} denegados`;
});

// Documentos de prueba en dos dependencias.
let docA, docB;
await caso("TEST-CAR-01", "RF-AC-008", "Cargar un documento: queda por clasificar", async () => {
  docA = esperar(await ac("POST", "/documentos", formDocumento(depA.id, ANIO - 3, `doc-a-${SUFIJO}`)), 201, "carga A");
  docB = esperar(await ac("POST", "/documentos", formDocumento(depB.id, ANIO - 3, `doc-b-${SUFIJO}`)), 201, "carga B");
  exigir(docA.estado === "por_clasificar", `estado ${docA.estado}`);
  return `documento ${docA.id}`;
});
await caso("TEST-CAR-02", "RN-AC-11", "Mismo archivo en el mismo expediente se rechaza", async () => {
  const r = await ac("POST", "/documentos", formDocumento(depA.id, ANIO - 3, `doc-a-${SUFIJO}`));
  exigir(r.status === 409, `respondió ${r.status}`);
  return r.json?.error ?? "409";
});
await caso("TEST-CLA-01", "RF-AC-011", "Por clasificar lista el documento y el archivo se descarga por id", async () => {
  const l = esperar(await ac("GET", "/documentos?estado=por_clasificar&limite=50"), 200, "lista");
  const filas = Array.isArray(l) ? l : l.datos ?? l.documentos ?? [];
  exigir(filas.some((d) => d.id === docA.id), "no aparece");
  const d = await ac("GET", `/archivos/${docA.archivo_id}`);
  exigir(d.status === 200 && d.texto.startsWith("%PDF"), `descarga ${d.status}`);
  exigir(!JSON.stringify(filas).includes("ruta_relativa"), "expone la ruta");
});
await caso("TEST-CLA-03", "RF-AC-011", "Clasificar: pasa a clasificados con asunto y TRD", async () => {
  const c = esperar(await ac("POST", `/documentos/${docA.id}/clasificar`, { asunto_id: asuntoA.id, fecha: `${ANIO - 3}-05-10`, tipo: "ENT", consecutivo: "385", remitente: "Remitente Ficticio", carro: "C1", estante: "E1", bandeja: "B1", caja: "1", carpeta: "1" }), 200, "clasificar");
  exigir(c.estado === "clasificado", `estado ${c.estado}`);
  const l = esperar(await ac("GET", "/clasificados?limite=50"), 200, "clasificados");
  exigir((Array.isArray(l) ? l : l.datos).some((d) => d.id === docA.id), "no aparece en clasificados");
});
await caso("TEST-ARB-01", "RF-AC-013", "Árbol Dependencia → Año → Asunto con contadores", async () => {
  const a = esperar(await ac("GET", "/archivo/arbol"), 200, "árbol");
  const d = a.find((x) => x.dependencia_id === depA.id);
  exigir(d?.total >= 1 && d.anios.length >= 1, "sin datos");
  const soloDep = esperar(await dep("GET", "/archivo/arbol"), 200, "Dependencia");
  exigir(soloDep.every((x) => x.dependencia_id === depA.id), "Dependencia ve otras");
});
await caso("TEST-BUS-01", "RF-AC-014", "Búsqueda por año, dependencia, persona, TRD y texto", async () => {
  const consultas = [`anio=${ANIO - 3}`, `dependencia_id=${depA.id}`, "persona=Remitente%20Ficticio", `trd=T${SUFIJO}`, `texto=doc-a-${SUFIJO}`];
  let peor = 0;
  for (const c of consultas) {
    const t = performance.now();
    const r = esperar(await ac("GET", `/archivo/buscar?${c}`), 200, c);
    peor = Math.max(peor, performance.now() - t);
    exigir(r.filas.length >= 1, `sin resultados: ${c}`);
  }
  exigir(peor < 3000, `tardó ${peor} ms`);
  return `peor consulta ${Math.round(peor)} ms`;
});
await caso("TEST-BUS-02", "RF-AC-014", "Consecutivo en varias formas; fecha imposible no rompe", async () => {
  const q = (v) => ac("GET", `/archivo/buscar?consecutivo=${encodeURIComponent(v)}`);
  const a = esperar(await q("385"), 200, "número");
  exigir(a.filas.some((f) => String(f.consecutivo).includes("385")), "no encuentra 385");
  esperar(await q("385 del 29 de febrero"), 200, "fecha");
  esperar(await q(`194/${ANIO - 2}`), 200, "barra");
  esperar(await q("30 de febrero"), 200, "fecha imposible");
});
await caso("TEST-PER-01", "RF-AC-023", "Cada perfil ve solo lo que le corresponde", async () => {
  esperar(await dep("GET", "/documentos?estado=por_clasificar"), 403, "Dep por clasificar");
  esperar(await ra("GET", "/documentos?estado=por_clasificar"), 403, "RA por clasificar");
  esperar(await ra("GET", "/archivo/arbol"), 403, "RA árbol");
  esperar(await sg("GET", "/archivo/arbol"), 200, "SG consulta");
  esperar(await sg("POST", `/documentos/${docB.id}/clasificar`, { asunto_id: asuntoA.id, fecha: `${ANIO - 3}-01-01`, carro: "C", estante: "E", bandeja: "B", caja: "1", carpeta: "1" }), 403, "SG clasifica");
  const c = await sg("POST", "/documentos", formDocumento(depB.id, ANIO - 3, `sg-${SUFIJO}`));
  exigir(c.status === 403, `Secretaría General carga documentos: ${c.status}`);
  const l = esperar(await dep("GET", "/clasificados?limite=50"), 200, "Dep clasificados");
  exigir((Array.isArray(l) ? l : l.datos).every((d) => (d.dependencia?.id ?? depA.id) === depA.id), "Dependencia ve otras");
  const b = esperar(await dep("GET", `/archivo/buscar?dependencia_id=${depB.id}`), 200, "Dep busca otra");
  exigir(b.filas.every((f) => (f.dependencia_id ?? depA.id) === depA.id), "Dependencia encuentra otras");
});
pendiente("TEST-PER-02", "SGD-091", "Bloqueo del login temporal", "No aplica: el login temporal se retiró (SGD-091). El acceso depende de NOVA.");
await caso("TEST-ANU-01", "RF-AC-024", "Anular documento exige motivo y no borra", async () => {
  esperar(await ac("POST", `/documentos/${docB.id}/anular`, {}), 400, "sin motivo");
  esperar(await ac("POST", `/documentos/${docB.id}/anular`, { motivo: "Prueba de anulación" }), 200, "con motivo");
  exigir(sql(`select estado from documento where id = ${docB.id}`) === "anulado", "no quedó anulado");
});

await caso("TEST-CLA-06", "RF-AC-011", "Editar un documento clasificado guarda en la base y lo audita", async () => {
  esperar(await ac("POST", `/documentos/${docA.id}/clasificar`, { remitente: "Remitente Corregido", carro: "C2", clasificar: false }), 200, "guardar");
  exigir(sql(`select remitente || '|' || carro || '|' || estado from documento where id = ${docA.id}`) === "Remitente Corregido|C2|clasificado", "no se guardó");
  esperar(await sg("POST", `/documentos/${docA.id}/clasificar`, { remitente: "No", clasificar: false }), 403, "Secretaría General");
});
await caso("TEST-INI-01", "RF-AC-023", "Inicio con datos reales por perfil y sin denegados en la auditoría", async () => {
  const antes = sql("select count(*) from auditoria where resultado = 'denegado'");
  const a = esperar(await ac("GET", "/inicio"), 200, "Archivo Central");
  exigir(typeof a.por_clasificar === "number" && typeof a.historias === "number", JSON.stringify(a));
  const d = esperar(await adm("GET", "/inicio"), 200, "Administrador");
  exigir(d.por_clasificar === null && d.historias === null, "Administrador ve documentos");
  const r = esperar(await ra("GET", "/inicio"), 200, "Registro Académico");
  exigir(r.por_clasificar === null && typeof r.historias === "number", JSON.stringify(r));
  exigir(sql("select count(*) from auditoria where resultado = 'denegado'") === antes, "abrir el panel audita denegados");
  esperar(await llamar(null, "GET", "/inicio"), 401, "sin token");
});

// ── C. Transferencias ────────────────────────────────────────────────────────
const anioPermitido = ANIO - 2;
let trfFisica;
await caso("TEST-TRF-01", "RF-AC-009", "Transferencia física con cajas y ubicación", async () => {
  trfFisica = esperar(await ac("POST", "/transferencias", { dependencia: depA.nombre, anio: anioPermitido, tipo: "fisica", contenido: "Inventario de prueba", responsable: "Responsable Ficticio", cajas: [{ caja: "1", carro: "C1", estante: "E1", bandeja: "B1" }] }), 201, "registrar");
  const d = esperar(await ac("GET", `/transferencias/${trfFisica.id}`), 200, "detalle");
  return `${d.codigo ?? trfFisica.id}`;
});
await caso("TEST-TRF-02", "RN-AC-03", "Año actual − 1 no se puede transferir", async () => {
  esperar(await ac("POST", "/transferencias", { dependencia: depA.nombre, anio: ANIO - 1, tipo: "fisica", contenido: "No permitida", responsable: "R", cajas: [{ caja: "1", carro: "C", estante: "E", bandeja: "B" }] }), 400, "año");
});
await caso("TEST-TRF-03", "RF-AC-010", "Transferencia digital con archivos y sin duplicar", async () => {
  const t = esperar(await ac("POST", "/transferencias", { dependencia: depB.nombre, anio: anioPermitido, tipo: "digital", contenido: "Digital de prueba", responsable: "R" }), 201, "digital");
  const f = () => { const x = new FormData(); x.set("archivo", pdf(`trf-${SUFIJO}`), `trf-${SUFIJO}.pdf`); return x; };
  esperar(await ac("POST", `/transferencias/${t.id}/documentos`, f()), 201, "archivo");
  const rep = await ac("POST", `/transferencias/${t.id}/documentos`, f());
  exigir(rep.status === 409 || rep.status === 200, `repetido ${rep.status}`);
  const n = sql(`select count(*) from transferencia_archivo where transferencia_id = ${t.id}`);
  exigir(n === "1", `${n} archivos`);
});
await caso("TEST-TRF-04", "SGD-095", "Transferencias exigen sesión y Dependencia solo las suyas", async () => {
  esperar(await llamar(null, "GET", "/transferencias"), 401, "sin token");
  esperar(await dep("POST", "/transferencias", { dependencia: depB.nombre, anio: anioPermitido, tipo: "fisica", contenido: "x", responsable: "R", cajas: [{ caja: "1", carro: "C", estante: "E", bandeja: "B" }] }), 403, "otra dependencia");
});

// ── E. Comunicaciones ────────────────────────────────────────────────────────
const correo = (n, extra = {}) => ({ message_id: `<f05-${SUFIJO}-${n}@ejemplo.test>`, de_nombre: "Remitente Ficticio", de_correo: "remitente@ejemplo.test", asunto: `Correo ${n} ${SUFIJO}`, cuerpo: "Cuerpo ficticio", recibido_en: new Date().toISOString(), ...extra });
const com1 = esperar(await n8n("correos/nuevo", correo(1)), 200, "correo 1");
await caso("TEST-COM-01", "RF-AC-015", "Correo entra como ENT y el detalle trae historial", async () => {
  exigir(/^ENT-\d{4}-\d{6}$/.test(com1.consecutivo), com1.consecutivo);
  const d = esperar(await ac("GET", `/comunicaciones/${com1.id}`), 200, "detalle");
  exigir(d.estado === "nueva" && d.eventos.some((e) => e.tipo === "recepcion"), "sin evento de recepción");
  return com1.consecutivo;
});
await caso("TEST-COM-02", "RNF-AC-04", "Mismo Message-ID no duplica", async () => {
  const otra = esperar(await n8n("correos/nuevo", correo(1)), 200, "repetido");
  exigir(otra.id === com1.id, "creó otra");
  exigir(sql(`select count(*) from comunicacion where message_id = '<f05-${SUFIJO}-1@ejemplo.test>'`) === "1", "duplicado");
});
await caso("TEST-COM-03", "RF-AC-016", "Remitir a una dependencia con plazo en días hábiles", async () => {
  const r = esperar(await n8n("remisiones/remitir", { usuario: idUsuario("ac@ejemplo.test"), comunicacion_id: com1.id, dependencia_id: depA.id, plazo: 5, message_id: `<rem-${SUFIJO}@ejemplo.test>` }), 200, "remitir");
  const d = esperar(await ac("GET", `/comunicaciones/${com1.id}`), 200, "detalle");
  exigir(d.estado === "remitida" && d.fecha_limite, `estado ${d.estado}`);
  return `fecha límite ${r.fecha_limite ?? d.fecha_limite}`;
});
await caso("TEST-COM-05", "SGD-083", "Dos respuestas de la dependencia no se pierden", async () => {
  esperar(await n8n("correos/respuesta-dependencia", { comunicacion_id: com1.id, de_correo: depA.correo_oficial, asunto: "Respuesta 1", cuerpo: "Primera respuesta", message_id: `<r1-${SUFIJO}@ejemplo.test>` }), 200, "primera");
  esperar(await n8n("correos/respuesta-dependencia", { comunicacion_id: com1.id, de_correo: depA.correo_oficial, asunto: "Respuesta 2", cuerpo: "Segunda respuesta", message_id: `<r2-${SUFIJO}@ejemplo.test>` }), 200, "segunda");
  const d = esperar(await ac("GET", `/comunicaciones/${com1.id}`), 200, "detalle");
  const n = d.eventos.filter((e) => e.tipo === "respuesta_dependencia").length;
  exigir(n === 2 && d.estado === "respondida_dependencia", `${n} respuestas, ${d.estado}`);
});
await caso("TEST-COM-08", "SGD-082", "El historial abre el correo de cada paso", async () => {
  const d = esperar(await ac("GET", `/comunicaciones/${com1.id}`), 200, "detalle");
  const ev = d.eventos.find((e) => e.tipo === "respuesta_dependencia");
  const c = esperar(await ac("GET", `/comunicaciones/${com1.id}/eventos/${ev.id}/correo`), 200, "correo");
  exigir(JSON.stringify(c).includes("respuesta"), "sin contenido");
});
await caso("TEST-COM-07", "RF-AC-017", "Responder al remitente crea SAL y cierra la entrada", async () => {
  const r = esperar(await n8n("respuestas/responder", { usuario: idUsuario("ac@ejemplo.test"), entrada_id: com1.id, asunto: "Respuesta final", cuerpo: "Respuesta ficticia", message_id: `<sal-${SUFIJO}@ejemplo.test>` }), 200, "responder");
  const d = esperar(await ac("GET", `/comunicaciones/${com1.id}`), 200, "detalle");
  exigir(d.estado === "cerrada", `estado ${d.estado}`);
  exigir(sql(`select count(*) from comunicacion where tipo = 'SAL' and comunicacion_entrada_id = ${com1.id}`) === "1", "sin SAL");
  return r.consecutivo ?? "SAL creada";
});
await caso("TEST-ANU-02", "RF-AC-024", "Anular comunicación: no se borra y queda en el historial", async () => {
  const c = esperar(await n8n("correos/nuevo", correo(2)), 200, "correo");
  esperar(await ac("POST", `/comunicaciones/${c.id}/anular`, {}), 400, "sin motivo");
  const a = esperar(await ac("POST", `/comunicaciones/${c.id}/anular`, { motivo: "Prueba" }), 200, "anular");
  exigir(a.estado === "anulada" && a.eventos.some((e) => e.tipo === "anulacion"), "sin evento");
});
await caso("TEST-COM-11", "RF-AC-018", "Correo sin asociar se convierte en comunicación", async () => {
  esperar(await n8n("correos/sin-asociar", { message_id: `<sa-${SUFIJO}@ejemplo.test>`, de_correo: "externo@ejemplo.test", asunto: "Sin asociar", cuerpo: "Ficticio", motivo: "sin_etiqueta" }), 200, "guardar");
  const l = esperar(await ac("GET", "/correos-sin-asociar"), 200, "lista");
  const item = l.find((x) => x.message_id === `<sa-${SUFIJO}@ejemplo.test>`);
  exigir(item, "no aparece");
  esperar(await ac("POST", `/correos-sin-asociar/${item.id}/crear`, {}), 200, "crear");
  const l2 = esperar(await ac("GET", "/correos-sin-asociar"), 200, "lista");
  exigir(!l2.some((x) => x.id === item.id), "sigue sin asociar");
});
await caso("TEST-COM-13", "RF-AC-019", "Importar histórico: vista previa y sin duplicar", async () => {
  const filas = [
    { tipo: "ENT", numero_original: `H${SUFIJO}`, fecha: `${ANIO - 2}-03-04`, asunto: "Histórico válido", remitente: "Ficticio" },
    { tipo: "ENT", numero_original: `E${SUFIJO}`, fecha: "no-es-fecha", asunto: "Fecha inválida" },
  ];
  const p = esperar(await ac("POST", "/comunicaciones/historico/importar", { filas, confirmar: false }), 200, "vista previa");
  esperar(await ac("POST", "/comunicaciones/historico/importar", { filas, confirmar: true }), 200, "confirmar");
  esperar(await ac("POST", "/comunicaciones/historico/importar", { filas, confirmar: true }), 200, "otra vez");
  const n = sql(`select count(*) from comunicacion where consecutivo_original = 'H${SUFIJO}'`);
  exigir(n === "1", `${n} copias`);
  return JSON.stringify(p).slice(0, 80);
});
await caso("TEST-COM-12", "RF-AC-019", "Calendario histórico por año y mes", async () => {
  const h = esperar(await ac("GET", `/comunicaciones/historico?anio=${ANIO - 2}`), 200, "año");
  exigir(h.meses?.find((m) => m.mes === 3)?.total >= 1, "marzo sin datos");
  esperar(await ac("GET", `/comunicaciones/historico/mes?anio=${ANIO - 2}&mes=3`), 200, "mes");
});
await caso("TEST-COM-14", "SGD-044", "Secretaría General consulta el histórico pero no importa", async () => {
  esperar(await sg("GET", `/comunicaciones/historico?anio=${ANIO - 2}`), 200, "consulta");
  esperar(await sg("POST", "/comunicaciones/historico/importar", { filas: [{ numero_original: "x", fecha: "2020-01-01", asunto: "x" }] }), 403, "importar");
});

// ── Triaje (D-32) ────────────────────────────────────────────────────────────
const comT = esperar(await n8n("correos/nuevo", correo(3)), 200, "correo");
await caso("TEST-TRI-01", "D-32", "F1 guarda el triaje de la IA, sin cambiar el estado", async () => {
  esperar(await n8n("correos/triaje", { comunicacion_id: comT.id, categoria: "urgente", prioridad: "alta", resumen: "Resumen ficticio" }), 200, "guardar");
  const d = esperar(await ac("GET", `/comunicaciones/${comT.id}`), 200, "detalle");
  exigir(d.categoria === "urgente" && d.triaje_origen === "ia" && d.estado === "nueva", "datos");
});
await caso("TEST-TRI-02", "D-32", "Marcar leído y reclasificar; la IA no pisa lo manual", async () => {
  const a = esperar(await ac("PATCH", `/comunicaciones/${comT.id}`, { leido: true, categoria: "academico" }), 200, "patch");
  exigir(a.leido_en && a.categoria === "academico" && a.triaje_origen === "manual", "cambios");
  esperar(await n8n("correos/triaje", { comunicacion_id: comT.id, categoria: "otros", prioridad: "baja" }), 200, "IA");
  const d = esperar(await ac("GET", `/comunicaciones/${comT.id}`), 200, "detalle");
  exigir(d.categoria === "academico", "la IA pisó");
});
await caso("TEST-TRI-03", "D-32", "Solo Archivo Central reclasifica y lo denegado queda auditado", async () => {
  esperar(await dep("PATCH", `/comunicaciones/${comT.id}`, { leido: false }), 403, "Dependencia");
  esperar(await llamar(null, "PATCH", `/comunicaciones/${comT.id}`, { leido: false }), 401, "sin token");
  esperar(await ac("PATCH", `/comunicaciones/${comT.id}`, { categoria: "inventada" }), 400, "valor");
  esperar(await ac("PATCH", "/comunicaciones/99999999", { leido: true }), 404, "no existe");
});
await caso("TEST-TRI-04", "D-32", "Estadísticas y filtros de los webhooks (backend de F7)", async () => {
  const e = esperar(await n8n("triaje/estadisticas"), 200, "estadísticas");
  exigir(e.total >= 1 && e.por_categoria && e.por_prioridad, "forma");
  const l = esperar(await n8n("triaje/correos", { categoria: "academico", q: `Correo 3 ${SUFIJO}` }), 200, "lista");
  exigir(l.total === 1, `total ${l.total}`);
  esperar(await n8n("triaje/actualizar", { id: 99999999, leido: true }), 404, "no existe");
});

// ── F. Archivos, errores y seguridad ─────────────────────────────────────────
await caso("TEST-ARC-01", "SGD-008", "Archivo que no está en disco: 404 sin mostrar la ruta", async () => {
  const hash = createHash("sha256").update(`perdido-${SUFIJO}`).digest("hex");
  const id = sql(`insert into archivo (ruta_relativa, nombre_original, extension, mime, tamano_bytes, hash_sha256) values ('perdidos/${SUFIJO}.pdf', 'perdido.pdf', 'pdf', 'application/pdf', 10, '${hash}') returning id`).split("\n")[0].trim();
  // Se liga a un documento para que el permiso por recurso lo deje pasar.
  sql(`insert into documento (archivo_id, hash_sha256, dependencia_id, anio, origen) select '${id}', '${hash}', ${depA.id}, ${ANIO - 4}, origen from documento limit 1`);
  const r = await ac("GET", `/archivos/${id}`);
  exigir(r.status === 404 || r.status === 500, `respondió ${r.status}`);
  exigir(!r.texto.includes("perdidos/") && !r.texto.includes("/data/"), "muestra la ruta");
  return `${r.status}: ${r.texto.slice(0, 80)}`;
});
await caso("TEST-ERR-01", "SGD-089", "Error de formulario con campo; sin detalles internos", async () => {
  const f = esperar(await adm("POST", "/catalogos/dependencias", { nombre: "Sin código" }), 400, "formulario");
  exigir(f.error && f.campo === "codigo", JSON.stringify(f));
  exigir(!/SQL|postgres|pg_|stack/i.test(JSON.stringify(f)), "detalle interno");
});
await caso("TEST-SEG-01", "RF-AC-023", "Sin token 401; token rechazado por NOVA 401", async () => {
  esperar(await llamar(null, "GET", "/comunicaciones"), 401, "sin token");
  esperar(await llamar("token-falso", "GET", "/comunicaciones"), 401, "token falso");
  esperar(await llamar("token-falso", "POST", "/n8n/triaje/estadisticas", {}), 401, "API de n8n");
});
await caso("TEST-SEG-02", "RN-AC-12", "No existe borrado físico por API (D-4)", async () => {
  const r = await ac("DELETE", `/comunicaciones/${comT.id}/eliminar`);
  exigir(r.status === 404 || r.status === 405, `respondió ${r.status}`);
  exigir(sql(`select count(*) from comunicacion where id = ${comT.id}`) === "1", "se borró");
  let denegado = false;
  try { execFileSync(SQL_CMD[0], [...SQL_CMD.slice(1), `set role sgd_backend; delete from comunicacion where id = ${comT.id}`], { encoding: "utf8", stdio: "pipe" }); } catch { denegado = true; }
  exigir(denegado, "sgd_backend pudo borrar");
});
await caso("TEST-SEG-03", "RNF-AC-02", "CORS solo para el origen permitido", async () => {
  const permitido = process.env.ORIGEN ?? "http://localhost:5173";
  const si = await fetch(`${API}/comunicaciones`, { method: "OPTIONS", headers: { Origin: permitido, "Access-Control-Request-Method": "PATCH" } });
  exigir(si.headers.get("access-control-allow-origin") === permitido, "no permite el origen válido");
  const no = await fetch(`${API}/comunicaciones`, { method: "OPTIONS", headers: { Origin: "https://malo.ejemplo", "Access-Control-Request-Method": "GET" } });
  exigir(no.headers.get("access-control-allow-origin") !== "https://malo.ejemplo", "permite otro origen");
});

// ── Casos que dependen de una persona o de servicios externos ────────────────
const HUMANOS = [
  ["TEST-CAR-03", "RF-AC-007", "Lote con avance, informe y reintento", "Pantalla: verificar en Centro de cargas durante el piloto."],
  ["TEST-CAR-04", "UI", "Píldoras de carga y paginación de lotes", "Pantalla."],
  ["TEST-CLA-02", "SGD-085", "Visor en Clasificados", "Pantalla."],
  ["TEST-CLA-04", "SGD-088", "Clic en la fila abre la previsualización", "Pantalla."],
  ["TEST-CLA-05", "UI", "Paginación en Por clasificar y Clasificados", "Pantalla."],
  ["TEST-COM-04", "RF-AC-016", "Respuesta sin etiqueta con In-Reply-To", "Requiere n8n F1 y Gmail reales."],
  ["TEST-COM-06", "D-20", "Responder directo al remitente", "Requiere n8n F3 y Gmail reales."],
  ["TEST-COM-09", "SGD-083", "Correo adicional a otra dependencia", "Requiere n8n F5 y Gmail reales."],
  ["TEST-COM-10", "RF-AC-018", "Recordatorios automáticos y manuales", "Requiere n8n F4 y Gmail reales."],
];
for (const [id, req, d, m] of HUMANOS) pendiente(id, req, d, m);

// ── Rendimiento (SGD-070, RNF-AC-01) ─────────────────────────────────────────
if (process.env.RENDIMIENTO === "1") {
  const CANTIDAD = 50000;
  await caso("TEST-REN-01", "RNF-AC-01", `Consultas con ${CANTIDAD} documentos en menos de 3 s`, async () => {
    sql(`with a as (
           insert into archivo (ruta_relativa, nombre_original, extension, mime, tamano_bytes, hash_sha256)
           select 'rendimiento/' || g || '.pdf', 'documento-' || g || '.pdf', 'pdf', 'application/pdf', 1000, encode(sha256(('r' || g)::bytea), 'hex')
             from generate_series(1, ${CANTIDAD}) g
           returning id, hash_sha256, nombre_original)
         insert into documento (archivo_id, hash_sha256, titulo, dependencia_id, anio, asunto_id, consecutivo, fecha_documento, remitente, estado, origen)
         select a.id, a.hash_sha256, a.nombre_original, ${depA.id}, 2000 + (row_number() over ()) % 24, ${asuntoA.id},
                ((row_number() over ()))::text, date '2000-01-01' + ((row_number() over ()) % 8000)::int, 'Remitente ' || ((row_number() over ()) % 500), 'clasificado',
                (select origen from documento limit 1)
           from a;
         analyze documento; analyze archivo;`);
    const medidas = {};
    for (const [nombre, ruta] of [
      ["Archivo (árbol)", "/archivo/arbol"],
      ["Buscar por año", "/archivo/buscar?anio=2010"],
      ["Buscar por persona", "/archivo/buscar?persona=Remitente%2042"],
      ["Buscar por texto", "/archivo/buscar?texto=documento-4999"],
      ["Buscar por consecutivo", "/archivo/buscar?consecutivo=4999"],
      ["Clasificados", "/clasificados?limite=20"],
    ]) {
      const t = performance.now();
      try {
        esperar(await ac("GET", ruta), 200, nombre);
      } catch (e) {
        throw new Error(`${nombre}: ${e.message} ${e.cause?.message ?? ""} (${JSON.stringify(medidas)})`);
      }
      medidas[nombre] = Math.round(performance.now() - t);
    }
    const lentas = Object.entries(medidas).filter(([, ms]) => ms >= 3000);
    exigir(!lentas.length, `lentas: ${JSON.stringify(lentas)}`);
    return Object.entries(medidas).map(([k, v]) => `${k}: ${v} ms`).join("; ");
  });
}

nova.close();
const cuenta = (r) => resultados.filter((x) => x.resultado === r).length;
console.log(`\nOK ${cuenta("OK")} · Falló ${cuenta("Falló")} · Revisión humana ${cuenta("Revisión humana")} · Total ${resultados.length}`);
if (process.env.SALIDA) writeFileSync(process.env.SALIDA, JSON.stringify({ fecha: new Date().toISOString(), resultados }, null, 2));
process.exit(cuenta("Falló") ? 1 : 0);
