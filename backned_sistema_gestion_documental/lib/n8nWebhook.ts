/**
 * @file lib/n8nWebhook.ts
 * @description Dispara webhooks de n8n desde el backend (acciones manuales del frontend).
 */

export async function dispararWebhookN8N(
  url: string | undefined,
  payload: Record<string, unknown>,
): Promise<unknown> {
  if (!url) {
    throw new Error("Webhook de n8n no configurado (falta la variable de entorno)");
  }

  const token = process.env.N8N_SERVICE_TOKEN;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(payload),
  });

  const text = await res.text().catch(() => "Error en n8n");
  let json: unknown = null;
  try {
    json = JSON.parse(text);
  } catch {
    // n8n a veces devuelve texto plano; continuamos con null.
  }

  if (!res.ok) {
    const detalle =
      typeof json === "object" && json !== null && "error" in json
        ? String((json as { error: string }).error)
        : text;
    throw Object.assign(new Error(`n8n respondió ${res.status}: ${detalle}`), { status: res.status });
  }

  return json;
}
