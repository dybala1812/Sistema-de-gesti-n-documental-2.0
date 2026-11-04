/**
 * GET /api/salud
 * Prueba de vida para Docker y el balanceador: responde 200 si el servidor está arriba.
 * No consulta la base de datos ni pide token; no devuelve datos del sistema.
 */
import { connection, NextResponse } from "next/server";

export async function GET() {
  await connection(); // se responde en cada petición, no en el build
  return NextResponse.json({ ok: true });
}
