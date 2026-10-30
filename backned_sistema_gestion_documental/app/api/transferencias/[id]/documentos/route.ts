/**
 * POST /api/transferencias/[id]/documentos  (multipart: archivo)
 * Transferencia DIGITAL (RF-AC-010): guarda UNO de los documentos que entregó la dependencia,
 * tal como llegó, junto a la transferencia (con su acta de entrega). NO pasa a "Por clasificar".
 * Una transferencia física no lleva archivos: sus cajas se quedan en bodega.
 * Si el archivo ya está en esta transferencia (misma huella) responde 409 y no se guarda otra vez.
 * Permiso cargas.transferencia. Función SQL: fn_transferencia_agregar_archivo (migración 22).
 */
import { createHash } from "node:crypto";
import { NextRequest } from "next/server";
import { obtenerUsuarioAutenticado } from "../../../../../lib/auth";
import { guardarArchivo } from "../../../../../lib/archivos";
import { rpc, tienePermiso } from "../../../../../lib/catalogos";
import { SolicitudInvalida, idRuta } from "../../../../../lib/n8n";
import { supabase } from "../../../../../lib/supabase";
import { errorResponse, errorSistema, forbidden, handleError, jsonResponse, notFound } from "../../../../../lib/errors";

const MIGRACION = "20261022000000_transferencia_archivos.sql";
/** Los documentos llegan como los tenía la dependencia: PDF, imagen, Word o Excel. */
const EXT_PERMITIDAS = ["pdf", "jpg", "jpeg", "png", "tif", "tiff", "doc", "docx", "xls", "xlsx"];
const MAX_BYTES = 50 * 1024 * 1024;

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const usuario = await obtenerUsuarioAutenticado(request);
    if (!(await tienePermiso(usuario.id, "cargas.transferencia"))) {
      return forbidden("No tiene permiso para esta acción: requiere el permiso cargas.transferencia");
    }
    const transferenciaId = idRuta(await params);

    const { data: t, error } = await supabase
      .from("transferencia").select("id, tipo, anio, anulado_en").eq("id", transferenciaId).maybeSingle();
    if (error) throw error;
    if (!t) return notFound("No existe la transferencia");
    if (String(t.tipo) !== "digital") {
      return errorResponse("Solo las transferencias digitales llevan archivos: las cajas de una física se quedan en bodega", 409, {
        campo: "tipo", tipo: "estado",
      });
    }

    const form = await request.formData();
    const archivo = form.get("archivo");
    if (!(archivo instanceof File)) throw new SolicitudInvalida("Campo 'archivo' es obligatorio", "archivo", "obligatorio");
    const ext = archivo.name.split(".").pop()?.toLowerCase() ?? "";
    if (!EXT_PERMITIDAS.includes(ext)) throw new SolicitudInvalida("Formato no permitido. Usa PDF, imagen, Word o Excel", "archivo", "formato");
    if (archivo.size === 0) throw new SolicitudInvalida("El archivo está vacío", "archivo", "vacio");
    if (archivo.size > MAX_BYTES) throw new SolicitudInvalida("El archivo supera los 50 MB", "archivo", "tamano");

    // Duplicado en esta transferencia: se revisa antes de guardar para no dejar archivos sueltos.
    const buffer = Buffer.from(await archivo.arrayBuffer());
    const hash = createHash("sha256").update(buffer).digest("hex");
    const { data: repetido, error: eRep } = await supabase
      .from("transferencia_archivo").select("id").eq("transferencia_id", transferenciaId).eq("hash_sha256", hash)
      .is("anulado_en", null).limit(1);
    if (eRep) {
      if (eRep.code === "42P01" || eRep.code === "PGRST205") {
        return errorSistema("MIGRACION", 500, { detalle: `ejecute database/supabase/migrations/${MIGRACION} en el SQL Editor de Supabase` });
      }
      throw eRep;
    }
    if (repetido && repetido.length > 0) {
      return errorResponse("Ese archivo ya está en esta transferencia", 409, { campo: "archivo", tipo: "duplicado" });
    }

    const guardado = await guardarArchivo(buffer, archivo.name, "transferencias", { anio: t.anio, transferencia_id: t.id }, usuario);
    const ligado = await rpc<Record<string, unknown>>("fn_transferencia_agregar_archivo", {
      p_usuario_id: usuario.id, p_transferencia_id: transferenciaId, p_archivo_id: guardado.archivo_id,
    }, MIGRACION);

    return jsonResponse({ ok: true, archivo_id: guardado.archivo_id, nombre: guardado.nombre_original, id: ligado.id }, 201);
  } catch (err) {
    if (err instanceof SolicitudInvalida) {
      return errorResponse(err.message, 400, { campo: err.campo, tipo: err.tipo });
    }
    return handleError(err);
  }
}
