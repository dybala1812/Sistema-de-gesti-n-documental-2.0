/**
 * GET /api/salud
 * Prueba de vida para Docker y el balanceador: 200 {ok, bd: true} si el servidor está arriba y
 * llega a PostgreSQL; 503 {ok: false, bd: false} si no hay conexión con la base.
 * No pide token ni devuelve datos del sistema.
 */
import { connection, NextResponse } from "next/server";
import { bdDisponible } from "../../../lib/db";

export async function GET() {
  await connection(); // se responde en cada petición, no en el build
  const bd = process.env.DATABASE_URL ? await bdDisponible() : false;
  return NextResponse.json({ ok: bd, bd }, { status: bd ? 200 : 503 });
}
