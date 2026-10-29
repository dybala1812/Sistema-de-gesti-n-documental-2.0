/**
 * @file lib/consecutivoTexto.ts
 * @description Interpreta lo que el usuario escribe en "consecutivo" de la búsqueda avanzada (RF-AC-014):
 *   "385"                       → { consecutivo: "385" }
 *   "385 del 29 de febrero"     → { consecutivo: "385", dia: 29, mes: 2 }
 *   "385 del 29/02/2024"        → { consecutivo: "385", dia: 29, mes: 2, anio: 2024 }
 *   "ENT-2026-000041"           → { consecutivo: "41", anio: 2026, tipo: "ENT" }
 * Sin imports: se prueba directo con `node --test` (tests/busqueda.test.mjs).
 */

export interface ConsecutivoBuscado {
  consecutivo?: string;
  dia?: number;
  mes?: number;
  anio?: number;
  tipo?: "ENT" | "SAL" | "INT";
}

const MESES: Record<string, number> = {
  enero: 1, febrero: 2, marzo: 3, abril: 4, mayo: 5, junio: 6, julio: 7, agosto: 8,
  septiembre: 9, setiembre: 9, octubre: 10, noviembre: 11, diciembre: 12,
};

const sinTildes = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();

export function interpretarConsecutivo(texto: string | null | undefined): ConsecutivoBuscado {
  const s = sinTildes(texto ?? "").replace(/\s+/g, " ");
  if (!s) return {};

  // Consecutivo del sistema: ENT|SAL|INT-AAAA-NNNNNN
  const sistema = /^(ent|sal|int)-(\d{4})-(\d{1,9})$/.exec(s);
  if (sistema) {
    return { tipo: sistema[1].toUpperCase() as "ENT" | "SAL" | "INT", anio: Number(sistema[2]), consecutivo: String(Number(sistema[3])) };
  }

  // Número al inicio ("385", "385/2024", "n° 385")
  const numero = /^(?:no\.?|n[°º]|numero)?\s*(\d{1,9})(?:\/(\d{4}))?/.exec(s);
  if (!numero) return { consecutivo: texto?.trim() };
  const r: ConsecutivoBuscado = { consecutivo: String(Number(numero[1])) };
  if (numero[2]) r.anio = Number(numero[2]);

  const resto = s.slice(numero[0].length);
  // "del 29 de febrero [de 2024]"
  const conMes = /(\d{1,2}) de ([a-z]+)(?: (?:de|del) (\d{4}))?/.exec(resto);
  if (conMes && MESES[conMes[2]]) {
    r.dia = Number(conMes[1]);
    r.mes = MESES[conMes[2]];
    if (conMes[3]) r.anio = Number(conMes[3]);
    return r;
  }
  // "del 29/02/2024" o "29-02"
  const conBarras = /(\d{1,2})[/-](\d{1,2})(?:[/-](\d{4}))?/.exec(resto);
  if (conBarras) {
    const dia = Number(conBarras[1]);
    const mes = Number(conBarras[2]);
    if (dia >= 1 && dia <= 31 && mes >= 1 && mes <= 12) {
      r.dia = dia;
      r.mes = mes;
      if (conBarras[3]) r.anio = Number(conBarras[3]);
    }
  }
  return r;
}
