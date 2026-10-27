/**
 * Pruebas del contrato de errores (RN-AC-15, SGD-089).
 * Ejecutar: npm test  (node --test; Node 24 carga lib/errors.ts directamente).
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ERRORES_SISTEMA, errorFormulario, errorSistema, errorResponse, handleError,
  columnaDuplicada, consecutivoDuplicado, unauthorized,
} from "../lib/errors.ts";

const leer = async (r) => ({ status: r.status, cuerpo: await r.json() });

test("error de formulario: descripción y campo, sin número ni consecutivo", async () => {
  const { status, cuerpo } = await leer(errorFormulario("Ya existe un registro con ese código", 409, { campo: "codigo", tipo: "duplicado" }));
  assert.equal(status, 409);
  assert.deepEqual(cuerpo, { error: "Ya existe un registro con ese código", campo: "codigo", tipo: "duplicado" });
  assert.equal("motivo" in cuerpo, false);
  assert.equal("consecutivo" in cuerpo, false);
});

test("error de formulario nunca sale con estado 5xx", async () => {
  assert.equal((await leer(errorFormulario("x", 500))).status, 400);
});

test("error de sistema: número del catálogo y motivo", async () => {
  const { status, cuerpo } = await leer(errorSistema("BASE_DATOS"));
  assert.equal(status, 500);
  assert.deepEqual(cuerpo, { error: "1001", motivo: ERRORES_SISTEMA.BASE_DATOS.motivo });
});

test("el consecutivo solo aparece en errores del contador", async () => {
  const conConsecutivo = await leer(errorSistema("CONSECUTIVO_EXISTENTE", 500, { consecutivo: "ENT-2026-000123" }));
  assert.equal(conConsecutivo.cuerpo.error, "1011");
  assert.equal(conConsecutivo.cuerpo.consecutivo, "ENT-2026-000123");
  const sinConsecutivo = await leer(errorSistema("BASE_DATOS", 500, { consecutivo: "ENT-2026-000123" }));
  assert.equal("consecutivo" in sinConsecutivo.cuerpo, false);
});

test("los números del catálogo no se repiten", () => {
  const numeros = Object.values(ERRORES_SISTEMA).map((e) => e.numero);
  assert.equal(new Set(numeros).size, numeros.length);
});

test("errorResponse elige la forma según el código HTTP", async () => {
  const f = await leer(errorResponse("Datos inválidos", 400, { detalle: "cuerpo es obligatorio", campo: "cuerpo" }));
  assert.deepEqual(f.cuerpo, { error: "Datos inválidos: cuerpo es obligatorio", campo: "cuerpo" });
  const s = await leer(errorResponse("Falta la función", 500, { codigo: "PGRST202" }));
  assert.equal(s.cuerpo.error, ERRORES_SISTEMA.MIGRACION.numero);
  assert.match(s.cuerpo.motivo, /Falta la función/);
});

test("handleError: validación con campo → formulario 400", async () => {
  const e = Object.assign(new Error("El asunto es obligatorio"), { campo: "asunto", tipo: "requerido" });
  assert.deepEqual((await leer(handleError(e))).cuerpo, { error: "El asunto es obligatorio", campo: "asunto", tipo: "requerido" });
});

test("handleError: error con status 4xx conserva el status", async () => {
  const e = Object.assign(new Error("Formato no permitido"), { status: 415 });
  const r = await leer(handleError(e));
  assert.equal(r.status, 415);
  assert.equal(r.cuerpo.error, "Formato no permitido");
});

test("handleError: archivo ausente → 1005 sin exponer la ruta", async () => {
  const e = Object.assign(new Error("ENOENT: no such file, open 'D:/archivos_sgd/2026/x.pdf'"), { code: "ENOENT" });
  const r = await leer(handleError(e));
  assert.equal(r.cuerpo.error, "1005");
  assert.doesNotMatch(r.cuerpo.motivo, /archivos_sgd/);
});

test("handleError: Response pasa tal cual", async () => {
  const r = unauthorized();
  assert.equal(handleError(r), r);
});

test("columnaDuplicada: clave compuesta devuelve la columna escrita por el usuario", () => {
  assert.equal(columnaDuplicada("Key (dependencia_id, lower(nombre::text))=(3, actas) already exists."), "nombre");
  assert.equal(columnaDuplicada("Key (codigo)=(TH) already exists."), "codigo");
  assert.equal(columnaDuplicada("Key (lower(correo_oficial::text))=(a@b.co) already exists."), "correo_oficial");
  assert.equal(columnaDuplicada(null), undefined);
});

test("consecutivoDuplicado: formatea tipo-año-número", () => {
  assert.equal(consecutivoDuplicado("Key (tipo, anio, numero)=(ENT, 2026, 123) already exists."), "ENT-2026-000123");
  assert.equal(consecutivoDuplicado("Key (consecutivo)=(SAL-2026-000007) already exists."), "SAL-2026-000007");
  assert.equal(consecutivoDuplicado("Key (codigo)=(X) already exists."), undefined);
});

test("handleError: n8n caído → 1004 (no es error de formulario)", async () => {
  const e = Object.assign(new Error("Workflow could not be started"), { servicio: "n8n", statusExterno: 404 });
  const r = await leer(handleError(e));
  assert.equal(r.status, 502);
  assert.equal(r.cuerpo.error, "1004");
  assert.match(r.cuerpo.motivo, /n8n respondió 404/);
});

test("handleError: webhook sin configurar → 1003", async () => {
  const e = Object.assign(new Error("Webhook de n8n no configurado"), { configuracion: true });
  assert.equal((await leer(handleError(e))).cuerpo.error, "1003");
});
