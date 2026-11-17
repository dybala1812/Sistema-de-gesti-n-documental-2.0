/**
 * POST /api/n8n/triaje/correos — F7 (GET /correos)
 * Correos de entrada con filtros por categoría, prioridad, leído, urgentes y búsqueda; paginado.
 * Función SQL: n8n_triaje_listar. Convenciones en lib/n8n.ts.
 */
import { leer, rutaN8N } from "../../../../../lib/n8n";

export const POST = rutaN8N({
  funcion: "n8n_triaje_listar",
  parametros: (b) => ({
    p_categoria: leer.texto(b, "categoria"),
    p_prioridad: leer.texto(b, "prioridad"),
    p_leido: leer.booleano(b, "leido"),
    p_urgentes: leer.booleano(b, "urgentes"),
    p_q: leer.texto(b, "q"),
    p_limite: leer.entero(b, "limite"),
    p_pagina: leer.entero(b, "pagina"),
  }),
});
