/**
 * Genera la clave de servicio (JWT con rol service_role) que el backend usa con PostgREST.
 * Equivale a la "service_role key" de Supabase, pero firmada con el JWT_SECRET propio.
 *
 * Uso:  JWT_SECRET='<mínimo 32 caracteres>' node database/scripts/generar_clave_servicio.mjs
 * Copiar el resultado en SERVICE_ROLE_KEY de despliegue/.env. No la pegue en chats ni correos.
 */
import { createHmac } from "node:crypto";

const secreto = process.env.JWT_SECRET ?? "";
if (secreto.length < 32) {
  console.error("JWT_SECRET debe tener al menos 32 caracteres");
  process.exit(1);
}
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
const cuerpo = `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ role: "service_role", iss: "sgd", iat: Math.floor(Date.now() / 1000) })}`;
const firma = createHmac("sha256", secreto).update(cuerpo).digest("base64url");
console.log(`${cuerpo}.${firma}`);
