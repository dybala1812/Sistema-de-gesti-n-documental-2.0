/**
 * Pruebas de la interpretación del consecutivo en la búsqueda avanzada (RF-AC-014, SGD-032).
 * Ejecutar: npm test
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { interpretarConsecutivo } from "../lib/consecutivoTexto.ts";

test("solo el número", () => {
  assert.deepEqual(interpretarConsecutivo("385"), { consecutivo: "385" });
  assert.deepEqual(interpretarConsecutivo("0385"), { consecutivo: "385" });
});

test("número con fecha en palabras (ejemplo del F-02)", () => {
  assert.deepEqual(interpretarConsecutivo("385 del 29 de febrero"), { consecutivo: "385", dia: 29, mes: 2 });
  assert.deepEqual(interpretarConsecutivo("385 del 29 de Febrero de 2024"), { consecutivo: "385", dia: 29, mes: 2, anio: 2024 });
  assert.deepEqual(interpretarConsecutivo("12 del 1 de septiembre"), { consecutivo: "12", dia: 1, mes: 9 });
});

test("número con fecha en cifras", () => {
  assert.deepEqual(interpretarConsecutivo("385 del 29/02/2024"), { consecutivo: "385", dia: 29, mes: 2, anio: 2024 });
  assert.deepEqual(interpretarConsecutivo("385 29-02"), { consecutivo: "385", dia: 29, mes: 2 });
});

test("número con año (194/2024) y prefijos", () => {
  assert.deepEqual(interpretarConsecutivo("194/2024"), { consecutivo: "194", anio: 2024 });
  assert.deepEqual(interpretarConsecutivo("N° 385"), { consecutivo: "385" });
});

test("consecutivo del sistema", () => {
  assert.deepEqual(interpretarConsecutivo("ENT-2026-000041"), { tipo: "ENT", anio: 2026, consecutivo: "41" });
});

test("vacío y texto sin número", () => {
  assert.deepEqual(interpretarConsecutivo(""), {});
  assert.deepEqual(interpretarConsecutivo(null), {});
  assert.deepEqual(interpretarConsecutivo("abc"), { consecutivo: "abc" });
});

test("una fecha imposible no se toma como fecha", () => {
  assert.deepEqual(interpretarConsecutivo("385 del 45/13"), { consecutivo: "385" });
});
