/**
 * Autenticación y autorización del SGD.
 *
 * Flujo:
 *  1. El frontend/envía un token de NOVA en el header Authorization: Bearer <token>.
 *  2. El backend lo valida contra GET /api/users/perfil/ de NOVA.
 *  3. Se sincroniza el usuario en la tabla `usuario` con fn_sincronizar_usuario_nova.
 *  4. Se verifica que tenga perfil asignado y esté activo.
 */
import { timingSafeEqual } from "crypto";
import { supabase, assertSupabaseConfig } from "./supabase";

export type PerfilSGD =
  | "archivo_central"
  | "dependencia"
  | "registro_academico"
  | "secretaria_general"
  | "administrador";

export type UsuarioSGD = {
  id: number;
  nova_user_id: string;
  email: string;
  nombre: string;
  apellido: string;
  perfil: PerfilSGD | null;
  dependencia_id: number | null;
  nova_is_staff: boolean;
  nova_roles: string[];
};

type PerfilNova = {
  id: string;
  email: string;
  username?: string;
  nombre?: string;
  apellido?: string;
  tipo_documento?: string;
  cedula?: string;
  telefono?: string;
  dependency?:
    | {
        id: string;
        name?: string;
        code?: string;
        email?: string;
      }
    | string;
  roles?: string[];
  is_staff?: boolean;
  activo?: boolean;
  perfil_tipo?: string;
  [key: string]: unknown;
};

const NOVA_API_URL = process.env.NOVA_API_URL?.replace(/\/$/, "");

async function fetchPerfilNova(token: string): Promise<PerfilNova> {
  if (!NOVA_API_URL) {
    throw new Error("Falta la variable de entorno NOVA_API_URL");
  }
  const res = await fetch(`${NOVA_API_URL}/api/users/perfil/`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });
  if (!res.ok) {
    throw new Error(`NOVA respondió ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) as PerfilNova;
}

// ── SOLO DESARROLLO: token de pruebas ──────────────────────────────────────
// Con `next dev` (NODE_ENV !== "production") y SGD_DEV_TOKEN definido, ese token
// se acepta sin consultar a NOVA y representa a un usuario de prueba de Archivo
// Central (se sincroniza en la tabla `usuario` como cualquier otro). En
// producción (`next build` / `next start`) esta rama nunca se activa.
const PERFIL_NOVA_DESARROLLO: PerfilNova = {
  id: "00000000-0000-0000-0000-000000000000",
  email: "dev@localhost",
  username: "dev",
  nombre: "Usuario",
  apellido: "Desarrollo",
  tipo_documento: "CC",
  cedula: "0",
  roles: [],
  is_staff: false,
  activo: true,
  perfil_tipo: "admin_area",
};

function esTokenDesarrollo(token: string): boolean {
  const esperado = process.env.SGD_DEV_TOKEN;
  if (process.env.NODE_ENV === "production" || !esperado) return false;
  const a = Buffer.from(token);
  const b = Buffer.from(esperado);
  return a.length === b.length && timingSafeEqual(a, b);
}

export async function validarTokenNOVA(token: string): Promise<UsuarioSGD> {
  const esDesarrollo = esTokenDesarrollo(token);
  const perfil = esDesarrollo ? PERFIL_NOVA_DESARROLLO : await fetchPerfilNova(token);

  const { data: usuario, error } = await supabase.rpc("fn_sincronizar_usuario_nova", {
    p_perfil: perfil as unknown as Record<string, unknown>,
  });

  if (error) {
    throw new Error(`Error sincronizando usuario: ${error.message}`);
  }

  const u = Array.isArray(usuario) ? usuario[0] : usuario;

  // Usuario de prueba: perfil Archivo Central si aún no tiene uno asignado.
  if (esDesarrollo && !u.perfil) {
    const { error: errPerfil } = await supabase.from("usuario").update({ perfil: "archivo_central" }).eq("id", u.id);
    if (errPerfil) throw new Error(`Error asignando perfil de desarrollo: ${errPerfil.message}`);
    u.perfil = "archivo_central";
  }

  const { data: puede } = await supabase.rpc("fn_usuario_puede_ingresar", {
    p_usuario_id: u.id,
  });

  if (!puede) {
    throw new Response(JSON.stringify({ error: "Usuario sin acceso al módulo" }), { status: 403 });
  }

  return {
    id: u.id,
    nova_user_id: u.nova_user_id,
    email: u.email,
    nombre: u.nombre,
    apellido: u.apellido,
    perfil: u.perfil,
    dependencia_id: u.dependencia_id,
    nova_is_staff: u.nova_is_staff,
    nova_roles: u.nova_roles ?? [],
  };
}

export function extraerToken(request: Request): string | null {
  const auth = request.headers.get("authorization");
  if (!auth) return null;
  const [scheme, token] = auth.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) return null;
  return token;
}

/**
 * SOLO DESARROLLO: si SGD_DEV_TOKEN está configurado y el request lo envía,
 * se devuelve un usuario de prueba sin consultar NOVA. Útil cuando NOVA no
 * está disponible localmente. Nunca activar en producción.
 */
function usuarioDesarrollo(token: string): UsuarioSGD | null {
  const esperado = process.env.SGD_DEV_TOKEN;
  if (!esperado || process.env.NODE_ENV === "production") return null;
  const a = Buffer.from(token);
  const b = Buffer.from(esperado);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  return {
    id: 1,
    nova_user_id: "dev-user",
    email: "dev@localhost",
    nombre: "Usuario",
    apellido: "Desarrollo",
    perfil: "archivo_central",
    dependencia_id: null,
    nova_is_staff: true,
    nova_roles: ["ADMIN"],
  };
}

export async function obtenerUsuarioAutenticado(request: Request): Promise<UsuarioSGD> {
  assertSupabaseConfig();
  const token = extraerToken(request);
  if (!token) {
    throw new Response(JSON.stringify({ error: "Token requerido" }), { status: 401 });
  }
  const dev = usuarioDesarrollo(token);
  if (dev) return dev;
  return validarTokenNOVA(token);
}

/**
 * Verifica que el usuario tenga alguno de los perfiles permitidos.
 */
export function requerirPerfil(usuario: UsuarioSGD, perfiles: PerfilSGD[]): void {
  if (!usuario.perfil || !perfiles.includes(usuario.perfil)) {
    throw new Response(JSON.stringify({ error: "Perfil no autorizado" }), { status: 403 });
  }
}

/**
 * Indica si el usuario puede atender comunicaciones (Archivo Central o Administrador).
 */
export function puedeGestionarComunicaciones(usuario: UsuarioSGD): boolean {
  return usuario.perfil === "archivo_central" || usuario.perfil === "administrador";
}

/**
 * Indica si el usuario puede ver una comunicación asignada a una dependencia.
 */
export function puedeVerDependencia(usuario: UsuarioSGD, dependenciaId: number | null): boolean {
  if (puedeGestionarComunicaciones(usuario)) return true;
  if (usuario.perfil === "dependencia") {
    return dependenciaId !== null && usuario.dependencia_id === dependenciaId;
  }
  return false;
}

/**
 * Indica si la petición viene de n8n: Authorization: Bearer <N8N_SERVICE_TOKEN>.
 * Comparación en tiempo constante. Si la variable no está configurada, nadie pasa.
 */
export function esServicioN8N(request: Request): boolean {
  const esperado = process.env.N8N_SERVICE_TOKEN;
  const recibido = extraerToken(request);
  if (!esperado || !recibido) return false;
  const a = Buffer.from(recibido);
  const b = Buffer.from(esperado);
  return a.length === b.length && timingSafeEqual(a, b);
}
