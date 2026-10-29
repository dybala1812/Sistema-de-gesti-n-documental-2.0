/**
 * @file lib/loginTemporal.ts
 * @description ⚠️ TEMPORAL — BORRAR ANTES DEL DESPLIEGUE (lista completa en ia_contexto/login-temporal.md).
 *
 * Login de pruebas para revisar los permisos de cada perfil sin pasar por NOVA.
 *  - Solo funciona con `next dev` (NODE_ENV distinto de production) y SGD_LOGIN_TEMPORAL=true.
 *  - Una sola clave de pruebas, SGD_LOGIN_TEMPORAL_CLAVE (mínimo 12 caracteres), que vive solo en el
 *    .env.local del backend: nunca en el frontend.
 *  - Solo se entra como los usuarios ficticios de USUARIOS_PRUEBA (correo @prueba.sgd.test), nunca
 *    como un usuario real sincronizado desde NOVA.
 *  - Entrega un token de sesión firmado (HMAC-SHA256, 8 horas) con una llave aleatoria que vive en la
 *    memoria del proceso: reiniciar el backend cierra todas las sesiones temporales.
 *  - Los intentos fallidos se limitan por origen y quedan en la auditoría.
 */
import { createHash, createHmac, randomBytes, timingSafeEqual } from "crypto";
import { supabase } from "./supabase";
import type { PerfilSGD, UsuarioSGD } from "./auth";

export const PREFIJO_TOKEN_TEMPORAL = "sgdtmp.";
const DOMINIO_PRUEBA = "@prueba.sgd.test";
const DURACION_MS = 8 * 60 * 60 * 1000;
const MAX_FALLOS = 5;
const VENTANA_FALLOS_MS = 10 * 60 * 1000;

/** Usuarios ficticios, uno por perfil (Ley 1581: ningún dato real). */
export const USUARIOS_PRUEBA: Record<PerfilSGD, { novaId: string; nombre: string; descripcion: string }> = {
  archivo_central: {
    novaId: "00000000-0000-4000-8000-00000000a001",
    nombre: "Archivo Central",
    descripcion: "Cargas, clasificación, transferencias, comunicaciones e histórico",
  },
  administrador: {
    novaId: "00000000-0000-4000-8000-00000000a002",
    nombre: "Administrador",
    descripcion: "Catálogos, usuarios, parámetros, plantillas y auditoría",
  },
  dependencia: {
    novaId: "00000000-0000-4000-8000-00000000a003",
    nombre: "Dependencia",
    descripcion: "Ve y responde solo lo de su dependencia",
  },
  registro_academico: {
    novaId: "00000000-0000-4000-8000-00000000a004",
    nombre: "Registro Académico",
    descripcion: "Historias académicas activas",
  },
  secretaria_general: {
    novaId: "00000000-0000-4000-8000-00000000a005",
    nombre: "Secretaría General",
    descripcion: "Consulta documentos, comunicaciones e historias",
  },
};

const correoPrueba = (perfil: PerfilSGD) => `${perfil.replace(/_/g, ".")}${DOMINIO_PRUEBA}`;

export function loginTemporalActivo(): boolean {
  return process.env.NODE_ENV !== "production"
    && process.env.SGD_LOGIN_TEMPORAL === "true"
    && (process.env.SGD_LOGIN_TEMPORAL_CLAVE ?? "").length >= 12;
}

// Estado en memoria del proceso (globalThis sobrevive a la recarga en caliente de `next dev`).
const estado = globalThis as typeof globalThis & {
  __sgdLoginTemporal?: { llave: Buffer; fallos: Map<string, { n: number; desde: number }> };
};
function memoria() {
  estado.__sgdLoginTemporal ??= { llave: randomBytes(32), fallos: new Map() };
  return estado.__sgdLoginTemporal;
}

const b64 = (b: Buffer | string) => Buffer.from(b).toString("base64url");
const firmar = (datos: string) => createHmac("sha256", memoria().llave).update(datos).digest("base64url");

function iguales(a: string, b: string): boolean {
  // Se comparan los resúmenes (mismo largo) en tiempo constante.
  return timingSafeEqual(createHash("sha256").update(a).digest(), createHash("sha256").update(b).digest());
}

/** Error con código HTTP; handleError lo convierte en error de formulario. */
function fallo(mensaje: string, status: number, campo?: string, tipo = "obligatorio"): Error {
  return Object.assign(new Error(mensaje), { status, ...(campo ? { campo, tipo } : {}) });
}

async function auditar(usuarioId: number | null, resultado: "ok" | "denegado", detalle: Record<string, unknown>) {
  const { error } = await supabase.from("auditoria").insert({
    usuario_id: usuarioId, accion: "iniciar_sesion", recurso_tipo: "login_temporal",
    recurso_id: usuarioId ? String(usuarioId) : null, resultado, detalle,
  });
  if (error) console.error("[login temporal] no se pudo auditar", error.message);
}

export async function opcionesLoginTemporal() {
  const { data, error } = await supabase
    .from("dependencia").select("id, codigo, nombre").eq("estado", "activo").order("nombre");
  if (error) throw error;
  return {
    perfiles: (Object.keys(USUARIOS_PRUEBA) as PerfilSGD[]).map((perfil) => ({
      perfil, nombre: USUARIOS_PRUEBA[perfil].nombre, descripcion: USUARIOS_PRUEBA[perfil].descripcion,
    })),
    dependencias: data ?? [],
  };
}

export async function iniciarSesionTemporal(
  datos: { perfil?: unknown; dependencia_id?: unknown; clave?: unknown }, origen: string,
) {
  const mem = memoria();
  const ahora = Date.now();
  const previo = mem.fallos.get(origen);
  if (previo && ahora - previo.desde < VENTANA_FALLOS_MS && previo.n >= MAX_FALLOS) {
    throw fallo("Demasiados intentos fallidos. Espere unos minutos.", 429);
  }

  const perfil = String(datos.perfil ?? "") as PerfilSGD;
  if (!(perfil in USUARIOS_PRUEBA)) throw fallo("Elija un perfil", 400, "perfil");

  if (typeof datos.clave !== "string" || !iguales(datos.clave, process.env.SGD_LOGIN_TEMPORAL_CLAVE ?? "")) {
    const n = previo && ahora - previo.desde < VENTANA_FALLOS_MS ? previo.n + 1 : 1;
    mem.fallos.set(origen, { n, desde: n === 1 ? ahora : previo!.desde });
    await auditar(null, "denegado", { perfil, motivo: "clave incorrecta" });
    throw fallo("Clave incorrecta", 401, "clave", "credencial");
  }
  mem.fallos.delete(origen);

  let dependenciaId: number | null = null;
  if (perfil === "dependencia") {
    dependenciaId = Number(datos.dependencia_id);
    if (!Number.isInteger(dependenciaId) || dependenciaId <= 0) throw fallo("Elija la dependencia", 400, "dependencia_id");
    const { data: dep } = await supabase.from("dependencia").select("id").eq("id", dependenciaId).eq("estado", "activo").maybeSingle();
    if (!dep) throw fallo("La dependencia no existe o está inactiva", 400, "dependencia_id", "existente");
  }

  // Crea o actualiza el usuario ficticio del perfil con la misma función que usa NOVA.
  const ficticio = USUARIOS_PRUEBA[perfil];
  const { data: sincronizado, error: errSync } = await supabase.rpc("fn_sincronizar_usuario_nova", {
    p_perfil: {
      id: ficticio.novaId, email: correoPrueba(perfil), username: `prueba.${perfil}`,
      nombre: "Prueba", apellido: ficticio.nombre, roles: [], is_staff: false, activo: true, perfil_tipo: "prueba",
    },
  });
  if (errSync) throw errSync;
  const u = Array.isArray(sincronizado) ? sincronizado[0] : sincronizado;

  const { error: errPerfil } = await supabase.from("usuario")
    .update({ perfil, dependencia_id: dependenciaId, estado: "activo" }).eq("id", u.id);
  if (errPerfil) throw errPerfil;

  const expira = ahora + DURACION_MS;
  const carga = b64(JSON.stringify({ u: u.id, exp: expira }));
  const token = `${PREFIJO_TOKEN_TEMPORAL}${carga}.${firmar(carga)}`;
  await auditar(u.id, "ok", { perfil, dependencia_id: dependenciaId });

  let dependencia: string | null = null;
  if (dependenciaId) {
    const { data: dep } = await supabase.from("dependencia").select("nombre").eq("id", dependenciaId).maybeSingle();
    dependencia = dep?.nombre ?? null;
  }
  return {
    token,
    expira: new Date(expira).toISOString(),
    usuario: { id: u.id, nombre: "Prueba", apellido: ficticio.nombre, email: correoPrueba(perfil), perfil, dependencia_id: dependenciaId, dependencia },
  };
}

/** Valida un token temporal y devuelve el usuario ficticio, o null si no es válido o venció. */
export async function usuarioDeTokenTemporal(token: string): Promise<UsuarioSGD | null> {
  if (!loginTemporalActivo() || !token.startsWith(PREFIJO_TOKEN_TEMPORAL)) return null;
  const [carga, firma] = token.slice(PREFIJO_TOKEN_TEMPORAL.length).split(".");
  if (!carga || !firma || !iguales(firma, firmar(carga))) return null;
  let datos: { u?: unknown; exp?: unknown };
  try {
    datos = JSON.parse(Buffer.from(carga, "base64url").toString("utf8"));
  } catch {
    return null;
  }
  if (typeof datos.u !== "number" || typeof datos.exp !== "number" || datos.exp < Date.now()) return null;

  const { data: u } = await supabase.from("usuario")
    .select("id, nova_user_id, email, nombre, apellido, perfil, dependencia_id, nova_is_staff, nova_roles")
    .eq("id", datos.u).maybeSingle();
  // Defensa adicional: el token solo sirve para los usuarios ficticios.
  if (!u || !String(u.email).endsWith(DOMINIO_PRUEBA)) return null;
  const { data: puede } = await supabase.rpc("fn_usuario_puede_ingresar", { p_usuario_id: u.id });
  if (!puede) return null;
  return { ...u, nova_roles: u.nova_roles ?? [] } as UsuarioSGD;
}
