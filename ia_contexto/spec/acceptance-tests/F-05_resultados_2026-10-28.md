# F-05 — Hoja de resultados (borrador de la primera pasada)

**Verificador:** Claude (primera pasada automática por API) · falta la revisión humana de los casos de pantalla  
**Fecha:** 2026-10-28  
**Ambiente:** frontend `NOVA_FT` en `desarrollo-archivo-central` (76691ea) · backend `master` (f126503) · Supabase del proyecto · migraciones 16 a 20: **sí** (las rutas que dependen de ellas responden 200)  
**Perfiles probados con el login temporal:** Archivo Central ☑ Administrador ☑ Dependencia (Secretaría General, id 19) ☑ Registro Académico ☑ Secretaría General ☑  
**n8n F1–F5:** **inactivo** (`localhost:5678` no responde) → los casos de correo van N/A, como dice el plan.

**Cómo se probó:** con un script que entra con cada perfil del login temporal y llama al backend (`http://localhost:3000/api`), igual que lo hace la pantalla. Los casos que dependen de cómo se ve la pantalla quedan **Pendiente (pantalla)** para el verificador humano.  
**Datos creados (ficticios, prefijo `PRUEBA-F05`):** dependencia `PF05119851` (inactivada), TRD `PF05.119851`, dos asuntos, un tipo documental (inactivado), un programa, una ubicación, dos documentos PDF de prueba (id 9 anulado, id 10 por clasificar), la transferencia `TR-2026-006` (año 2024) y dos comunicaciones del histórico (`F05-…-A`, `F05-…-D`). No se borró nada (RN-AC-12).

| ID | Resultado | Evidencia breve |
|---|---|---|
| TEST-BD-01 | **Bloqueado** | La carpeta `C:\Program Files\PostgreSQL\18` solo tiene `data`, no tiene `bin` (sin `initdb`/`psql`). |
| TEST-CAT-01 | OK | 200; lista con código, nombre y correo. Sin borrado. |
| TEST-CAT-02 | OK (API) · Pendiente (pantalla) | Crear a mano: 201 (id 23). **SGD-087 ya no pasa.** Falta mirar en pantalla que el formulario no pida "dependencia superior" (la columna `dependencia_padre_id` sigue en los datos). |
| TEST-CAT-03 | OK | Código repetido → 409, campo `codigo`; correo repetido → 409, campo `correo_oficial`. |
| TEST-CAT-04 | OK | Inactivar sin motivo → 400; con motivo → 200; sigue en el filtro "inactivas". |
| TEST-CAT-05 | OK | Vista previa: 1 válida, 1 error (fila 2, `duplicado`, campo `codigo`); al confirmar solo entra la válida. |
| TEST-CAT-06 | OK | Mismo asunto en 2 dependencias → 201 y 201; repetido en la misma → 409. |
| TEST-CAT-07 | OK | Tipo documental: crear 201, repetido 409, editar 200, inactivar 200. Programa 201, ubicación 201. |
| TEST-CAT-08 | OK | Usuarios: id, nombre, apellido, email, username, perfil, estado, dependencia (sin cédula ni teléfono). Archivo Central no ve usuarios (403). |
| TEST-CAT-09 | OK | 9 parámetros, ninguno con códigos RF/RN (**SGD-090 ya no pasa**). `plazo_respuesta_dias_habiles` [1–60]: dentro 200, fuera 400 «El valor debe ser un número entero entre 1 y 60» (campo `valor`); se dejó el valor original. |
| TEST-CAT-10 | OK (API) · Pendiente (pantalla) | `acuse_recibo`: guardar 200, restablecer 200. La vista previa se mira en pantalla. Sin n8n: N/A el "siguiente correo". |
| TEST-AUD-01 | OK | Filtros por acción y recurso: 200, con valores previos y nuevos. `DELETE /api/auditoria` → 405. |
| TEST-AUD-02 | OK | Archivo Central → Auditoría 403 y cambiar parámetro 403; Dependencia → crear catálogo 403 («No tiene permiso para esta acción…»). Los 3 intentos aparecen como **denegados** en la auditoría con el usuario de prueba. |
| TEST-PER-01 | **Falló** | Archivo Central ve todo; Dependencia no entra a Por clasificar (403) y en árbol y búsqueda ve solo su dependencia; Registro Académico 403 en todo. **Defecto D-1:** Secretaría General **sí puede cargar** documentos (`POST /api/documentos` → 201, documento id 10). Nota: todos los clasificados actuales son de Secretaría General, así que el filtro de Dependencia en "Clasificados" no se pudo distinguir. |
| TEST-PER-02 | Pendiente | No se forzó desde aquí para no bloquearle el ingreso al verificador durante 10 minutos. La auditoría muestra 5 claves incorrectas a las 21:21 (hora local) que quedaron registradas como denegadas. |
| TEST-ANU-01 | OK | Sobre el documento de prueba (id 9): sin motivo 400, con motivo 200; deja de verse en Por clasificar; no se borra. |
| TEST-ANU-02 | Pendiente | No se anuló una comunicación real. El backend no deja crear comunicaciones de prueba (`POST /api/comunicaciones` → 501, "pendiente de implementar"). |
| TEST-CAR-01 | OK | PDF ficticio → 201, queda "por clasificar" (sin consecutivo ni tipo). |
| TEST-CAR-02 | OK | El mismo archivo otra vez → 409 «Archivo duplicado». |
| TEST-CAR-03 | N/A | Lotes reales no implementados (sección 3.2). |
| TEST-CAR-04 | Pendiente (pantalla) | |
| TEST-TRF-01 | OK con defecto | Física, año 2024, FUID de 1 carpeta → 201 `TR-2026-006`, acta `ACT-TR-2026-006`. **Defecto D-2:** ver abajo. |
| TEST-TRF-02 | OK | Año 2025 → 400 «Solo se puede transferir hasta 2024». |
| TEST-TRF-03 | N/A | Transferencia digital no implementada. |
| TEST-CLA-01 | Pendiente (pantalla) | La lista responde 200. |
| TEST-CLA-02 | Pendiente (pantalla) | La lista responde 200. |
| TEST-CLA-03 | **Falló** | **Defecto D-3:** el botón **Clasificar** no llama al backend (`ClasificarDocumento.tsx`: "Aún no llama al backend", `TODO` en `clasificar` y `guardar`) y no hay ruta en el backend para clasificar. |
| TEST-CLA-04 | Pendiente (pantalla) | SGD-088. |
| TEST-CLA-05 | Pendiente (pantalla) | |
| TEST-ARB-01 | OK (API) · Pendiente (pantalla) | Árbol 200 con 16 dependencias y su total; la pantalla falta. |
| TEST-BUS-01 | OK | Año, dependencia, tipo, persona, TRD y texto: 200, máximo 20 por página, todas en menos de 0,5 s. |
| TEST-BUS-02 | OK con observación | «385 del 29 de febrero» → 0, «194/2024» → 0, «ENT-2026-000029» → 1, «30 de febrero» → 1 resultado y no rompe. Falta comprobar con datos que tengan esos números (no hay ninguno 385 ni 194 en la base). |
| TEST-COM-01 | OK | 22 comunicaciones (nueva 1, remitida 2, cerrada 18, anulada 1), todas con formato `ENT\|SAL\|INT-AAAA-NNNNNN`. La vista de detalle se mira en pantalla. |
| TEST-COM-02 | N/A | Sin n8n. |
| TEST-COM-03 | N/A | Sin n8n (F2/F5). |
| TEST-COM-04 | N/A | Sin n8n. |
| TEST-COM-05 | N/A | Sin n8n. ENT-2026-000029 tiene solo 1 respuesta guardada (el segundo correo llegó antes de la migración 15, ya conocido). |
| TEST-COM-06 | N/A | Sin n8n (F3). |
| TEST-COM-07 | N/A | Sin n8n (F3/F5). |
| TEST-COM-08 | OK | En ENT-2026-000029 los 5 pasos devuelven el correo (de, para, asunto, cuerpo, fecha, adjuntos). |
| TEST-COM-09 | N/A | Sin n8n (F4/F5). |
| TEST-COM-10 | N/A | F4 no activo. |
| TEST-COM-11 | N/A | No hay correos sin asociar (0 ítems). |
| TEST-COM-12 | OK | 2026: solo octubre tiene datos (21); el mes lista consecutivo, fecha, remitente y asunto. |
| TEST-COM-13 | OK | La vista previa separa nuevas, a revisar (número repetido) y con error (2024-02-30); al confirmar solo entran las válidas; al repetir: `nuevas 0, ya_importadas 1`, **no duplica**. |
| TEST-COM-14 | OK | Secretaría General consulta (200) e importar se niega (403, `cargas.historico`). |
| TEST-ARC-01 | OK | Archivo inexistente → 404 «Archivo no encontrado», sin rutas del disco. |
| TEST-ERR-01 | OK | Formulario: 400 «nombre es obligatorio» con `campo` (sin número). No se provocó un error de sistema (todas las migraciones están). |
| TEST-UI-01 | Pendiente (pantalla) | |
| TEST-UI-02 | Pendiente (pantalla) | |
| TEST-UI-03 | Pendiente (pantalla) | |
| TEST-UI-04 | OK con observación | La pantalla no tiene ningún botón "eliminar definitivamente". **Observación D-4:** la ruta `DELETE /api/comunicaciones/{id}/eliminar` sigue existiendo sin restringirse a desarrollo. |
| TEST-UI-05 | Pendiente (pantalla) | |
| TEST-UI-06 | OK | Con el login temporal activo se ve **Ingresar** y **Login 2**, y no **Registrarse** (captura del 28/10 y `InstitutionalNavbar.tsx`). |

## Defectos nuevos

| # | Dónde | Qué pasó | Esperado |
|---|---|---|---|
| D-1 | `POST /api/documentos` (perfil Secretaría General) | Secretaría General carga documentos (201). Además, la detección de duplicado responde antes que el permiso (un archivo repetido da 409 aunque el perfil no pueda cargar). | Secretaría General solo consulta: 403 al cargar, y el permiso se revisa antes que el duplicado. |
| D-2 | `GET`/`POST /api/transferencias` | La ruta no pide sesión (`requireUser` comentado; `GET` sin token → 200), registra con `usuario_id: null` (la auditoría no sabe quién fue) y la función `registrar_transferencia` no está en ninguna migración del repositorio (solo existe en Supabase). | Exigir sesión y permiso, guardar el usuario autenticado y versionar la función en una migración. |
| D-3 | Por clasificar › Clasificar (`ClasificarDocumento.tsx`) | El botón no guarda nada en el backend; no existe ruta para clasificar. | Clasificar con expediente/TRD, sale de Por clasificar y aparece en Clasificados. |
| D-4 | `DELETE /api/comunicaciones/{id}/eliminar` | Borrado físico disponible sin restricción de entorno (choca con RN-AC-12). Ya estaba anotado el 08/10. | Responder 404 en producción, o quitar la ruta. |

**Defectos corregidos (sección 3.3):** SGD-087 OK · SGD-089 OK (errores de formulario con campo; error de sistema con número no provocado) · SGD-090 OK · SGD-088 pendiente de pantalla.

**Conclusión del verificador:** **con fallos bloqueantes** (TEST-PER-01 y TEST-CLA-03), más los casos de pantalla pendientes y los de n8n en N/A.
