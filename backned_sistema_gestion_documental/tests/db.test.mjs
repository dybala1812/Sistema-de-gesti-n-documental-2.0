/**
 * Prueba de integración de lib/db.ts contra un PostgreSQL de verdad.
 * Solo corre si se define SGD_DB_PRUEBAS_URL (nunca contra la base de producción: escribe filas).
 * La base debe tener las migraciones, seed.sql y seed_demo.sql, por ejemplo la de desarrollo:
 *   docker compose -f despliegue/docker-compose.dev.yml up -d
 *   docker compose -f despliegue/docker-compose.dev.yml exec db psql -U postgres -d sgd -f /database/seed_demo.sql
 *   SGD_DB_PRUEBAS_URL=postgres://sgd_backend:sgd_backend_dev@localhost:5432/sgd npm test
 */
import { test, after } from "node:test";
import assert from "node:assert/strict";

const URL_PRUEBAS = process.env.SGD_DB_PRUEBAS_URL;
const omitir = URL_PRUEBAS ? false : "sin SGD_DB_PRUEBAS_URL";
if (URL_PRUEBAS) process.env.DATABASE_URL = URL_PRUEBAS;
const { db } = URL_PRUEBAS ? await import("../lib/db.ts") : { db: null };
const sufijo = `${Date.now()}`;

after(async () => {
  await globalThis.__sgdPool?.end();
});

test("relación hacia el padre por columna llave: objeto", { skip: omitir }, async () => {
  const { data, error } = await db.from("asunto")
    .select("id, nombre, dependencia:dependencia_id(id, codigo, nombre), trd:trd_id ( codigo )")
    .order("nombre").limit(3);
  assert.equal(error, null);
  assert.equal(data.length, 3);
  assert.equal(typeof data[0].id, "number");
  assert.equal(typeof data[0].dependencia.codigo, "string");
  assert.deepEqual(Object.keys(data[0].trd), ["codigo"]);
});

test("relación hacia los hijos por nombre de tabla: lista; y relación anidada", { skip: omitir }, async () => {
  const { data, error } = await db.from("dependencia")
    .select("id, nombre, asuntos:asunto(id, nombre, trd:trd_id(codigo))").eq("estado", "activo").order("id");
  assert.equal(error, null);
  const con = data.find((d) => d.asuntos.length > 0);
  assert.ok(Array.isArray(con.asuntos));
  assert.equal(typeof con.asuntos[0].trd.codigo, "string");
});

test("or + ilike + count + range, y * en la raíz", { skip: omitir }, async () => {
  const { data, error, count } = await db.from("asunto").select("*", { count: "exact" })
    .or("nombre.ilike.%a%,descripcion.ilike.*a*").order("id", { ascending: false }).range(0, 1);
  assert.equal(error, null);
  assert.ok(count >= data.length);
  assert.ok(data.length <= 2);
  assert.ok("dependencia_id" in data[0]);
  assert.match(data[0].creado_en, /^\d{4}-\d{2}-\d{2}T/); // fechas en ISO, como antes
});

test("in, is null, maybeSingle y single", { skip: omitir }, async () => {
  const { data: varios } = await db.from("dependencia").select("id").in("id", [1, 2]).is("nova_dependency_id", null);
  assert.ok(Array.isArray(varios));
  const nada = await db.from("dependencia").select("id").eq("id", -1).maybeSingle();
  assert.equal(nada.error, null);
  assert.equal(nada.data, null);
  const sinFila = await db.from("dependencia").select("id").eq("id", -1).single();
  assert.equal(sinFila.error.code, "P0002");
});

test("insert con select y relación, update y llave única", { skip: omitir }, async () => {
  const { data: dep } = await db.from("dependencia").select("id").order("id").limit(1).single();
  const { data: trd } = await db.from("trd").select("id").order("id").limit(1).single();
  const nombre = `Asunto de prueba ${sufijo}`;
  const ins = await db.from("asunto")
    .insert({ dependencia_id: dep.id, trd_id: trd.id, nombre, descripcion: undefined })
    .select("id, nombre, dependencia:dependencia_id(id)").single();
  assert.equal(ins.error, null);
  assert.equal(ins.data.dependencia.id, dep.id);

  const upd = await db.from("asunto").update({ descripcion: "actualizado" }).eq("id", ins.data.id).select("descripcion");
  assert.equal(upd.error, null);
  assert.equal(upd.data[0].descripcion, "actualizado");

  const sinRetorno = await db.from("asunto").update({ descripcion: "otra" }).eq("id", ins.data.id);
  assert.deepEqual([sinRetorno.data, sinRetorno.error], [null, null]);

  const repetido = await db.from("asunto").insert({ dependencia_id: dep.id, trd_id: trd.id, nombre });
  assert.equal(repetido.error.code, "23505");
  assert.match(repetido.error.details, /\(dependencia_id, lower\(nombre\)\)/);
});

test("rpc: fila, booleano, conjunto y jsonb", { skip: omitir }, async () => {
  const u = await db.rpc("fn_sincronizar_usuario_nova", {
    p_perfil: { id: "99999999-9999-4999-8999-999999999999", email: `prueba.${sufijo}@ejemplo.test`, nombre: "Prueba", apellido: "Ficticia" },
  });
  assert.equal(u.error, null);
  assert.equal(typeof u.data.id, "number");

  const permiso = await db.rpc("fn_tiene_permiso", { p_usuario_id: u.data.id, p_funcion: "documentos.consultar" });
  assert.equal(permiso.error, null);
  assert.equal(typeof permiso.data, "boolean");

  const com = await db.rpc("fn_registrar_comunicacion_n8n", {
    p_message_id: `<prueba-${sufijo}@ejemplo.test>`, p_remitente_nombre: "Remitente Ficticio", p_remitente_correo: "remitente@ejemplo.test",
    p_asunto: "Prueba de integración", p_cuerpo: "Cuerpo", p_recibido_en: new Date().toISOString(), p_adjuntos: [],
  });
  assert.equal(com.error, null);
  assert.ok(Array.isArray(com.data));
  assert.match(com.data[0].consecutivo, /^ENT-\d{4}-\d{6}$/);

  // jsonb con una lista (se envía como JSON, no como arreglo de PostgreSQL).
  const imp = await db.rpc("fn_catalogo_importar", { p_usuario_id: u.data.id, p_tabla: "dependencia", p_filas: [{ codigo: "X" }], p_confirmar: false });
  assert.equal(imp.error, null);
  assert.equal(typeof imp.data, "object");
});

test("errores: función inexistente, relación inexistente y or() mal formado", { skip: omitir }, async () => {
  assert.equal((await db.rpc("fn_que_no_existe", { p_x: 1 })).error.code, "42883");
  assert.equal((await db.from("asunto").select("id, x:no_existe(id)")).error.code, "42703");
  assert.equal((await db.from("asunto").select("id").or("nombre.raro.x")).error.code, "42601");
  assert.equal((await db.from("tabla_que_no_existe").select("id")).error.code, "42P01");
});
