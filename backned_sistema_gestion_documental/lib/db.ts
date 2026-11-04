/**
 * Acceso a PostgreSQL del backend del SGD (driver pg, conexión directa; D-31).
 *
 * `db` ofrece dos formas de consultar, las dos devuelven { data, error, count } y no lanzan
 * por errores de la base (error trae el SQLSTATE de PostgreSQL, el mensaje y el detalle):
 *  - db.rpc("fn_x", { p_a: 1 })  ejecuta una función SQL con parámetros por nombre. Devuelve el
 *    valor (escalar o jsonb), la fila (función que devuelve una tabla/registro) o la lista
 *    (función que devuelve un conjunto).
 *  - db.from("tabla").select("id, dependencia:dependencia_id(nombre)").eq("estado", "activo")…
 *    lecturas y escrituras simples. Las relaciones se piden como alias:columna_fk(campos) o
 *    alias:tabla(campos) (también tabla!nombre_fk) y se resuelven con las llaves foráneas del
 *    catálogo de PostgreSQL: hacia el padre devuelve un objeto; hacia los hijos, una lista.
 *
 * La autorización la hace el backend (token de NOVA, permisos por perfil y dependencia, y las
 * funciones SQL que auditan). El rol de la conexión (sgd_backend) salta RLS; nadie más entra.
 * Nunca se registran en el log los parámetros de las consultas (Ley 1581).
 */
import { Pool } from "pg";

export interface DbError {
  message: string;
  /** SQLSTATE de PostgreSQL (23505, 42883…). 08006 = sin conexión con la base. */
  code?: string;
  details?: string | null;
  hint?: string | null;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export interface DbResult<T = any> {
  data: T;
  error: DbError | null;
  count: number | null;
}

// ── Conexión ────────────────────────────────────────────────────────────────

declare global {
  var __sgdPool: Pool | undefined;
}

/** Lanza un error de configuración si falta DATABASE_URL (se lee al arrancar, sirve en Docker). */
export function assertDbConfig(): void {
  if (!process.env.DATABASE_URL) {
    throw Object.assign(new Error("Falta DATABASE_URL: configure la conexión a PostgreSQL en las variables de entorno"), {
      configuracion: true,
    });
  }
}

function pool(): Pool {
  if (!globalThis.__sgdPool) {
    assertDbConfig();
    const nuevo = new Pool({
      connectionString: process.env.DATABASE_URL,
      max: Number(process.env.DATABASE_POOL_MAX) || 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
      application_name: "sgd-backend",
    });
    nuevo.on("error", (e) => console.error("[base de datos] conexión inactiva con error:", e.message));
    globalThis.__sgdPool = nuevo;
  }
  return globalThis.__sgdPool;
}

/** ¿Responde la base? Para /api/salud. */
export async function bdDisponible(): Promise<boolean> {
  try {
    await pool().query("select 1");
    return true;
  } catch {
    return false;
  }
}

function aDbError(e: unknown): DbError {
  const pg = e as { message?: string; code?: string; detail?: string; hint?: string; configuracion?: boolean };
  if (pg?.configuracion) throw e;
  if (typeof pg?.code === "string" && /^[0-9A-Z]{5}$/.test(pg.code)) {
    return { message: pg.message ?? "Error de la base de datos", code: pg.code, details: pg.detail ?? null, hint: pg.hint ?? null };
  }
  // ECONNREFUSED, ETIMEDOUT, clave equivocada al conectar…: se trata como "sin conexión".
  console.error("[base de datos] sin conexión:", pg?.code ?? "", pg?.message ?? e);
  return { message: "No hay conexión con la base de datos", code: "08006", details: null, hint: null };
}

const errorDe = (code: string, message: string): DbError => ({ message, code, details: null, hint: null });

// ── Catálogo de PostgreSQL (llaves foráneas, columnas y funciones) ───────────

interface Llave {
  nombre: string;
  tabla: string;
  columnas: string[];
  refTabla: string;
  refColumnas: string[];
}

interface Funcion {
  entradas: { nombre: string; tipo: string; conDefecto: boolean }[];
  conjunto: boolean;
  retorno: "void" | "escalar" | "fila";
}

interface Catalogo {
  llaves: Llave[];
  /** tabla → columna → tipo (para convertir a JSON las columnas json/jsonb). */
  columnas: Map<string, Map<string, string>>;
  funciones: Map<string, Funcion[]>;
}

let catalogo: Promise<Catalogo> | null = null;

async function cargarCatalogo(): Promise<Catalogo> {
  const [llaves, columnas, funciones] = await Promise.all([
    pool().query(`
      select c.conname as nombre, tc.relname as tabla, tr.relname as ref_tabla,
             array(select a.attname from unnest(c.conkey) with ordinality k(n, i)
                   join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.n order by k.i)::text[] as columnas,
             array(select a.attname from unnest(c.confkey) with ordinality k(n, i)
                   join pg_attribute a on a.attrelid = c.confrelid and a.attnum = k.n order by k.i)::text[] as ref_columnas
        from pg_constraint c
        join pg_class tc on tc.oid = c.conrelid
        join pg_namespace n on n.oid = tc.relnamespace
        join pg_class tr on tr.oid = c.confrelid
       where c.contype = 'f' and n.nspname = 'public'`),
    pool().query(`
      select c.relname as tabla, a.attname as columna, format_type(a.atttypid, a.atttypmod) as tipo
        from pg_attribute a
        join pg_class c on c.oid = a.attrelid
        join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p') and a.attnum > 0 and not a.attisdropped`),
    pool().query(`
      select p.proname as nombre, p.proretset as conjunto, rt.typname as tipo_retorno, rt.typtype as clase_retorno,
             p.pronargdefaults as n_defectos,
             coalesce(p.proargnames, '{}')::text[] as nombres,
             coalesce(p.proargmodes::text[], '{}') as modos,
             array(select format_type(x, null) from unnest(p.proargtypes) with ordinality u(x, i) order by i)::text[] as tipos
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        join pg_type rt on rt.oid = p.prorettype
       where n.nspname = 'public' and p.prokind = 'f'`),
  ]);

  const cols = new Map<string, Map<string, string>>();
  for (const r of columnas.rows) {
    if (!cols.has(r.tabla)) cols.set(r.tabla, new Map());
    cols.get(r.tabla)!.set(r.columna, r.tipo);
  }

  const fns = new Map<string, Funcion[]>();
  for (const r of funciones.rows) {
    const modos: string[] = r.modos;
    const nombres: string[] = r.nombres;
    // proargtypes trae solo las entradas (IN, INOUT, VARIADIC), en orden.
    const nombresEntrada = modos.length ? nombres.filter((_, i) => ["i", "b", "v"].includes(modos[i])) : nombres;
    const tipos: string[] = r.tipos;
    const entradas = tipos.map((tipo, i) => ({
      nombre: nombresEntrada[i] ?? "",
      tipo,
      conDefecto: i >= tipos.length - Number(r.n_defectos),
    }));
    const retorno: Funcion["retorno"] =
      r.tipo_retorno === "void" ? "void" : r.clase_retorno === "c" || r.tipo_retorno === "record" ? "fila" : "escalar";
    if (!fns.has(r.nombre)) fns.set(r.nombre, []);
    fns.get(r.nombre)!.push({ entradas, conjunto: r.conjunto, retorno });
  }

  return {
    llaves: llaves.rows.map((r) => ({
      nombre: r.nombre, tabla: r.tabla, columnas: r.columnas, refTabla: r.ref_tabla, refColumnas: r.ref_columnas,
    })),
    columnas: cols,
    funciones: fns,
  };
}

async function obtenerCatalogo(recargar = false): Promise<Catalogo> {
  if (!catalogo || recargar) {
    catalogo = cargarCatalogo();
    catalogo.catch(() => { catalogo = null; });
  }
  return catalogo;
}

// ── Utilidades SQL ───────────────────────────────────────────────────────────

const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;

class ErrorConsulta extends Error {
  dbError: DbError;
  constructor(dbError: DbError) {
    super(dbError.message);
    this.dbError = dbError;
  }
}

function q(ident: string): string {
  if (!IDENT.test(ident)) throw new ErrorConsulta(errorDe("42602", `Nombre no válido: ${ident}`));
  return `"${ident}"`;
}

const esJson = (tipo?: string) => tipo === "json" || tipo === "jsonb";

/** Valor JS → parámetro de pg. Objetos (y listas en columnas json) van como texto JSON. */
function aParametro(valor: unknown, tipo?: string): unknown {
  if (valor === null || valor === undefined) return null;
  if (esJson(tipo)) return JSON.stringify(valor);
  if (typeof valor === "object" && !Array.isArray(valor) && !(valor instanceof Date)) return JSON.stringify(valor);
  return valor;
}

class Parametros {
  valores: unknown[] = [];
  agregar(v: unknown): string {
    this.valores.push(v);
    return `$${this.valores.length}`;
  }
}

// ── Lista de campos: "id, alias:fk(campos), tabla!fk(*)" ─────────────────────

interface Campo {
  alias?: string;
  nombre: string;
  pista?: string;
  /** Si tiene hijos es una relación; si no, una columna (o "*"). */
  hijos?: Campo[];
}

function partirNivelCero(texto: string): string[] {
  const partes: string[] = [];
  let nivel = 0;
  let actual = "";
  let comillas = false;
  for (const ch of texto) {
    if (ch === '"') comillas = !comillas;
    if (!comillas && ch === "(") nivel++;
    if (!comillas && ch === ")") nivel--;
    if (!comillas && ch === "," && nivel === 0) {
      partes.push(actual);
      actual = "";
    } else {
      actual += ch;
    }
  }
  partes.push(actual);
  return partes.map((p) => p.trim()).filter(Boolean);
}

const CAMPO = /^(?:([A-Za-z_]\w*)\s*:\s*)?([A-Za-z_]\w*|\*)(?:\s*!\s*([A-Za-z_]\w*))?\s*(?:\(([\s\S]*)\))?$/;

function leerCampos(texto: string): Campo[] {
  return partirNivelCero(texto).map((parte) => {
    const m = CAMPO.exec(parte);
    if (!m) throw new ErrorConsulta(errorDe("42601", `Campo no válido en la consulta: ${parte}`));
    const [, alias, nombre, pista, interior] = m;
    return { alias, nombre, pista, hijos: interior !== undefined ? leerCampos(interior || "*") : undefined };
  });
}

// ── Relaciones por llave foránea ─────────────────────────────────────────────

interface Relacion {
  tabla: string;
  /** padre: la fila tiene la llave (objeto); hijos: la otra tabla apunta a la fila (lista). */
  tipo: "padre" | "hijos";
  /** Pares [columna en la otra tabla, columna en la fila]. */
  pares: [string, string][];
}

function resolverRelacion(cat: Catalogo, tabla: string, campo: Campo): Relacion {
  const { nombre, pista } = campo;
  const desdeFila = cat.llaves.filter((l) => l.tabla === tabla);
  const haciaFila = cat.llaves.filter((l) => l.refTabla === tabla);

  // alias:columna_fk(...) → la tabla a la que apunta esa columna.
  const porColumna = desdeFila.filter((l) => l.columnas.length === 1 && l.columnas[0] === nombre);
  if (porColumna.length === 1 && !pista) {
    const l = porColumna[0];
    return { tabla: l.refTabla, tipo: "padre", pares: [[l.refColumnas[0], l.columnas[0]]] };
  }

  // alias:tabla(...) o tabla!llave(...) → la llave entre las dos tablas.
  const coincide = (l: Llave) => !pista || l.nombre === pista || (l.columnas.length === 1 && l.columnas[0] === pista);
  const candidatos: Relacion[] = [
    ...desdeFila.filter((l) => l.refTabla === nombre && coincide(l)).map((l): Relacion => ({
      tabla: nombre, tipo: "padre", pares: l.refColumnas.map((c, i) => [c, l.columnas[i]]),
    })),
    ...haciaFila.filter((l) => l.tabla === nombre && coincide(l)).map((l): Relacion => ({
      tabla: nombre, tipo: "hijos", pares: l.columnas.map((c, i) => [c, l.refColumnas[i]]),
    })),
  ];
  if (candidatos.length === 1) return candidatos[0];
  if (candidatos.length > 1) {
    throw new ErrorConsulta(errorDe("42702", `Hay varias relaciones entre ${tabla} y ${nombre}: indique la llave con ${nombre}!nombre_fk`));
  }
  throw new ErrorConsulta(errorDe("42703", `La relación ${nombre} no existe desde la tabla ${tabla} (does not exist)`));
}

interface Expresion {
  clave: string | "*";
  sql: string;
}

function expresiones(cat: Catalogo, tabla: string, alias: string, campos: Campo[], contador: { n: number }): Expresion[] {
  return campos.map((campo): Expresion => {
    if (!campo.hijos) {
      if (campo.nombre === "*") return { clave: "*", sql: `${alias}.*` };
      return { clave: campo.alias ?? campo.nombre, sql: `${alias}.${q(campo.nombre)}` };
    }
    const rel = resolverRelacion(cat, tabla, campo);
    const hijo = `t${++contador.n}`;
    const objeto = objetoJson(hijo, expresiones(cat, rel.tabla, hijo, campo.hijos, contador));
    const union = rel.pares.map(([suya, mia]) => `${hijo}.${q(suya)} = ${alias}.${q(mia)}`).join(" and ");
    const sql = rel.tipo === "padre"
      ? `(select ${objeto} from ${q(rel.tabla)} ${hijo} where ${union} limit 1)`
      : `coalesce((select json_agg(${objeto}) from ${q(rel.tabla)} ${hijo} where ${union}), '[]'::json)`;
    return { clave: campo.alias ?? campo.nombre, sql };
  });
}

/** Objeto JSON de una fila embebida (json_build_object admite hasta 50 pares por llamada). */
function objetoJson(alias: string, exprs: Expresion[]): string {
  const conTodo = exprs.some((e) => e.clave === "*");
  const pares = exprs.filter((e) => e.clave !== "*").map((e) => `'${e.clave}', ${e.sql}`);
  if (!conTodo && pares.length <= 50) return `json_build_object(${pares.join(", ")})`;
  const trozos: string[] = conTodo ? [`to_jsonb(${alias})`] : [];
  for (let i = 0; i < pares.length; i += 50) trozos.push(`jsonb_build_object(${pares.slice(i, i + 50).join(", ")})`);
  return `(${trozos.join(" || ")})::json`;
}

function listaSelect(exprs: Expresion[]): string {
  return exprs.map((e) => (e.clave === "*" ? e.sql : `${e.sql} as ${q(e.clave)}`)).join(", ");
}

// ── Filtros ──────────────────────────────────────────────────────────────────

type Operador = "eq" | "neq" | "gt" | "gte" | "lt" | "lte" | "like" | "ilike" | "is" | "in";

type Filtro =
  | { columna: string; op: Operador; valor: unknown; negado?: boolean }
  | { o: Filtro[] };

const SIMBOLO: Record<Exclude<Operador, "is" | "in">, string> = {
  eq: "=", neq: "<>", gt: ">", gte: ">=", lt: "<", lte: "<=", like: "like", ilike: "ilike",
};

function filtroSql(f: Filtro, alias: string, p: Parametros): string {
  if ("o" in f) return `(${f.o.map((x) => filtroSql(x, alias, p)).join(" or ")})`;
  const col = `${alias}.${q(f.columna)}`;
  let sql: string;
  if (f.op === "is" || (f.op === "eq" && f.valor === null)) {
    sql = f.valor === null ? `${col} is null` : f.valor === true ? `${col} is true` : `${col} is false`;
  } else if (f.op === "in") {
    sql = `${col} = any(${p.agregar(f.valor)})`;
  } else {
    sql = `${col} ${SIMBOLO[f.op]} ${p.agregar(f.valor)}`;
  }
  return f.negado ? `not (${sql})` : sql;
}

/** Lee "columna.op.valor,columna.op.valor" (el formato de .or()). En like/ilike, * equivale a %. */
function leerO(expresion: string): Filtro {
  const partes = partirNivelCero(expresion).map((parte): Filtro => {
    const m = /^([A-Za-z_]\w*)\.(not\.)?(eq|neq|gt|gte|lt|lte|like|ilike|is)\.([\s\S]*)$/.exec(parte);
    if (!m) throw new ErrorConsulta(errorDe("42601", `Condición no válida en or(): ${parte}`));
    const [, columna, negado, op, crudo] = m;
    let valor: unknown = crudo.replace(/^"([\s\S]*)"$/, "$1");
    if (op === "like" || op === "ilike") valor = String(valor).replace(/\*/g, "%");
    if (op === "is") valor = crudo === "null" ? null : crudo === "true";
    return { columna, op: op as Operador, valor, negado: !!negado };
  });
  return { o: partes };
}

// ── Constructor de consultas sobre una tabla ─────────────────────────────────

/** T: lo que trae data (lista de filas; con single()/maybeSingle(), una fila). */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
class Consulta<T = any[]> implements PromiseLike<DbResult<T>> {
  private accion: "select" | "insert" | "update" = "select";
  private campos = "*";
  private devolver = false;
  private conteo = false;
  private filtros: Filtro[] = [];
  private orden: { columna: string; asc: boolean; nulosPrimero?: boolean }[] = [];
  private limite?: number;
  private desde?: number;
  private modo: "varios" | "uno" | "quizas" = "varios";
  private valores: Record<string, unknown>[] = [];

  private tabla: string;

  constructor(tabla: string) {
    this.tabla = tabla;
  }

  /** En una lectura, los campos; en insert/update, pide las filas resultantes. */
  select(campos = "*", opciones?: { count?: "exact" }): this {
    this.campos = campos;
    if (this.accion !== "select") this.devolver = true;
    this.conteo = opciones?.count === "exact";
    return this;
  }

  insert(valores: Record<string, unknown> | Record<string, unknown>[]): this {
    this.accion = "insert";
    this.valores = Array.isArray(valores) ? valores : [valores];
    return this;
  }

  update(valores: Record<string, unknown>): this {
    this.accion = "update";
    this.valores = [valores];
    return this;
  }

  private filtro(columna: string, op: Operador, valor: unknown): this {
    this.filtros.push({ columna, op, valor });
    return this;
  }
  eq(columna: string, valor: unknown) { return this.filtro(columna, "eq", valor); }
  neq(columna: string, valor: unknown) { return this.filtro(columna, "neq", valor); }
  gt(columna: string, valor: unknown) { return this.filtro(columna, "gt", valor); }
  gte(columna: string, valor: unknown) { return this.filtro(columna, "gte", valor); }
  lt(columna: string, valor: unknown) { return this.filtro(columna, "lt", valor); }
  lte(columna: string, valor: unknown) { return this.filtro(columna, "lte", valor); }
  like(columna: string, patron: string) { return this.filtro(columna, "like", patron); }
  ilike(columna: string, patron: string) { return this.filtro(columna, "ilike", patron); }
  is(columna: string, valor: null | boolean) { return this.filtro(columna, "is", valor); }
  in(columna: string, valores: readonly unknown[]) { return this.filtro(columna, "in", [...valores]); }

  or(expresion: string): this {
    try {
      this.filtros.push(leerO(expresion));
    } catch (e) {
      this.errorPrevio = e instanceof ErrorConsulta ? e.dbError : aDbError(e);
    }
    return this;
  }
  private errorPrevio: DbError | null = null;

  order(columna: string, opciones: { ascending?: boolean; nullsFirst?: boolean } = {}): this {
    this.orden.push({ columna, asc: opciones.ascending !== false, nulosPrimero: opciones.nullsFirst });
    return this;
  }

  limit(n: number): this {
    this.limite = n;
    return this;
  }

  /** Filas desde..hasta, contando desde 0 e incluyendo las dos. */
  range(desde: number, hasta: number): this {
    this.desde = desde;
    this.limite = hasta - desde + 1;
    return this;
  }

  /** Exige exactamente una fila (si no, error P0002 sin filas / P0003 varias). */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  single(): Consulta<any> {
    this.modo = "uno";
    return this;
  }

  /** Una fila o null (error P0003 si hay varias). */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  maybeSingle(): Consulta<any> {
    this.modo = "quizas";
    return this;
  }

  then<R1 = DbResult<T>, R2 = never>(
    ok?: ((v: DbResult<T>) => R1 | PromiseLike<R1>) | null,
    fallo?: ((e: unknown) => R2 | PromiseLike<R2>) | null,
  ): Promise<R1 | R2> {
    return (this.ejecutar() as Promise<DbResult<T>>).then(ok, fallo);
  }

  private where(alias: string, p: Parametros): string {
    return this.filtros.length ? ` where ${this.filtros.map((f) => filtroSql(f, alias, p)).join(" and ")}` : "";
  }

  private sufijo(alias: string): string {
    let sql = "";
    if (this.orden.length) {
      sql += " order by " + this.orden.map((o) =>
        `${alias}.${q(o.columna)} ${o.asc ? "asc" : "desc"}${o.nulosPrimero === undefined ? "" : o.nulosPrimero ? " nulls first" : " nulls last"}`,
      ).join(", ");
    }
    if (this.limite !== undefined) sql += ` limit ${Math.max(0, Math.floor(this.limite))}`;
    if (this.desde) sql += ` offset ${Math.max(0, Math.floor(this.desde))}`;
    return sql;
  }

  private async ejecutar(): Promise<DbResult> {
    if (this.errorPrevio) return { data: null, error: this.errorPrevio, count: null };
    try {
      const cat = await obtenerCatalogo();
      const p = new Parametros();
      const exprs = expresiones(cat, this.tabla, "t0", leerCampos(this.campos), { n: 0 });
      const tabla = q(this.tabla);
      let sql: string;

      if (this.accion === "select") {
        sql = `select coalesce(json_agg(r), '[]'::json) as filas from (select ${listaSelect(exprs)} from ${tabla} t0${this.where("t0", p)}${this.sufijo("t0")}) r`;
      } else {
        const tipos = cat.columnas.get(this.tabla);
        let mutacion: string;
        if (this.accion === "insert") {
          const columnas = [...new Set(this.valores.flatMap((v) => Object.keys(v).filter((k) => v[k] !== undefined)))];
          if (!columnas.length) return { data: null, error: errorDe("22023", "No hay datos para insertar"), count: null };
          const filas = this.valores.map((v) =>
            `(${columnas.map((c) => (v[c] === undefined ? "default" : p.agregar(aParametro(v[c], tipos?.get(c))))).join(", ")})`,
          );
          mutacion = `insert into ${tabla} as t0 (${columnas.map(q).join(", ")}) values ${filas.join(", ")}`;
        } else {
          const cambios = Object.entries(this.valores[0]).filter(([, v]) => v !== undefined);
          if (!cambios.length) return { data: null, error: errorDe("22023", "No hay datos para actualizar"), count: null };
          if (!this.filtros.length) return { data: null, error: errorDe("22023", "Actualizar exige al menos un filtro"), count: null };
          const set = cambios.map(([c, v]) => `${q(c)} = ${p.agregar(aParametro(v, tipos?.get(c)))}`).join(", ");
          mutacion = `update ${tabla} as t0 set ${set}${this.where("t0", p)}`;
        }
        if (!this.devolver) {
          await pool().query(mutacion, p.valores);
          return { data: null, error: null, count: null };
        }
        sql = `with m as (${mutacion} returning t0.*) select coalesce(json_agg(r), '[]'::json) as filas from (select ${listaSelect(exprs)} from m t0${this.sufijo("t0")}) r`;
      }

      const { rows } = await pool().query(sql, p.valores);
      const filas = (rows[0]?.filas ?? []) as unknown[];

      let count: number | null = null;
      if (this.conteo && this.accion === "select") {
        const pc = new Parametros();
        const res = await pool().query(`select count(*)::int as n from ${tabla} t0${this.where("t0", pc)}`, pc.valores);
        count = res.rows[0]?.n ?? 0;
      }

      if (this.modo === "varios") return { data: filas, error: null, count };
      if (filas.length > 1) return { data: null, error: errorDe("P0003", "La consulta devolvió varias filas"), count };
      if (filas.length === 0) {
        return this.modo === "uno"
          ? { data: null, error: errorDe("P0002", "La consulta no devolvió filas"), count }
          : { data: null, error: null, count };
      }
      return { data: filas[0], error: null, count };
    } catch (e) {
      return { data: null, error: e instanceof ErrorConsulta ? e.dbError : aDbError(e), count: null };
    }
  }
}

// ── Funciones SQL ────────────────────────────────────────────────────────────

function elegirFuncion(candidatas: Funcion[] | undefined, claves: string[]): Funcion | null {
  for (const f of candidatas ?? []) {
    const nombres = new Set(f.entradas.map((e) => e.nombre));
    const faltan = f.entradas.some((e) => !e.conDefecto && !claves.includes(e.nombre));
    if (!faltan && claves.every((k) => nombres.has(k))) return f;
  }
  return null;
}

async function rpc(funcion: string, parametros: Record<string, unknown> = {}): Promise<DbResult> {
  try {
    // Como en JSON, un parámetro undefined no se envía (toma su valor por defecto).
    const params = Object.fromEntries(Object.entries(parametros).filter(([, v]) => v !== undefined));
    const claves = Object.keys(params);
    let f = elegirFuncion((await obtenerCatalogo()).funciones.get(funcion), claves);
    if (!f) f = elegirFuncion((await obtenerCatalogo(true)).funciones.get(funcion), claves); // ¿migración nueva?
    if (!f) {
      return { data: null, error: errorDe("42883", `No existe la función ${funcion}(${claves.join(", ")}): falta aplicar una migración`), count: null };
    }

    const p = new Parametros();
    const args = claves.map((k) => {
      const tipo = f.entradas.find((e) => e.nombre === k)!.tipo;
      return `${q(k)} => ${p.agregar(aParametro(params[k], tipo))}::${tipo}`;
    });
    const llamada = `${q(funcion)}(${args.join(", ")})`;
    const sql =
      f.retorno === "void" ? `select ${llamada}, null::json as v`
      : f.conjunto ? `select coalesce(json_agg(t), '[]'::json) as v from ${llamada} t`
      : f.retorno === "fila" ? `select to_json(t) as v from ${llamada} t`
      : `select to_json(${llamada}) as v`;

    const { rows } = await pool().query(sql, p.valores);
    return { data: rows[0]?.v ?? null, error: null, count: null };
  } catch (e) {
    return { data: null, error: e instanceof ErrorConsulta ? e.dbError : aDbError(e), count: null };
  }
}

export const db = {
  from: (tabla: string) => new Consulta(tabla),
  rpc,
};
