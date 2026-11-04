/**
 * Helpers para ejecutar operaciones en Supabase atribuyendo la acción al usuario actual.
 */
import { supabase } from "./supabase";
import type { UsuarioSGD } from "./auth";

export async function setUsuarioActual(usuarioId: number): Promise<void> {
  await supabase.rpc("fn_set_usuario_actual", { p_usuario_id: usuarioId });
}

export async function withUsuario<T>(usuario: UsuarioSGD, fn: () => Promise<T>): Promise<T> {
  await setUsuarioActual(usuario.id);
  try {
    return await fn();
  } finally {
    await supabase.rpc("fn_set_usuario_actual", { p_usuario_id: null });
  }
}
