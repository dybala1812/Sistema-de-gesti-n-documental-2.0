/**
 * Cliente de Supabase para el backend del SGD.
 *
 * Usa la service role key para poder leer/escribir sin depender de RLS
 * (la autorización la hace el backend validando el token de NOVA).
 */
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const urlParaBuild = supabaseUrl ?? "https://placeholder.invalid";
const keyParaBuild = supabaseServiceKey ?? "placeholder";

export const supabase = createClient(urlParaBuild, keyParaBuild, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export function assertSupabaseConfig(): void {
  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error("Faltan variables de entorno de Supabase");
  }
}
