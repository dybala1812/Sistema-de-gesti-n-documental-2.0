# F-05 — Plan de pruebas (verificación humana)

**Módulo:** Archivo Central (SGD) · Universidad Autónoma del Cauca  
**Fecha del plan:** 2026-10-27  
**Versión:** 1.0 (borrador para el verificador)  
**Fuente de alcance:** tablero `ia_contexto/tareas-hechas.md` y `tareas-en-revision.md`  
**Requisitos:** F-02 v1.1 §8 · `ia_contexto/spec/requirements.md`

Este documento es lo que se pasa a **quien prueba**. No es una lista de todo el F-02: solo lo que ya está construido y se puede verificar en el entorno de desarrollo.

Marque cada caso: **OK** · **Falló** · **Bloqueado** · **N/A**.  
Datos: **siempre ficticios** (Ley 1581). No use cédulas, correos ni nombres reales.

---

## 1. Cómo llenar el resultado

| Marca | Cuándo |
|---|---|
| **OK** | El resultado coincide con lo esperado. |
| **Falló** | El resultado no coincide. Anote captura, mensaje en pantalla y (si puede) el JSON de error. |
| **Bloqueado** | No pudo ejecutar el caso (servidor apagado, falta migración, sin n8n, sin permiso). |
| **N/A** | El caso no aplica en este entorno (ej. F1 si n8n no está activo). |

Al final copie la **hoja de resumen** (sección 9) y devuélvala con su nombre, fecha y ambiente.

---

## 2. Ambiente

| Pieza | Cómo | URL típica |
|---|---|---|
| Frontend NOVA | En `NOVA_FT/`: `npm run dev` | `http://localhost:5173` |
| Backend SGD | En `backned_sistema_gestion_documental/`: `npm run dev` | `http://localhost:3000` |
| Base | Supabase del proyecto (migraciones aplicadas) | — |
| Entrada al módulo | Panel de Área de NOVA → **Archivo Central** (`/archivo-central`) | |

**Usuario de pruebas (desarrollo):** token de desarrollo (`VITE_SGD_DEV_TOKEN` / `SGD_DEV_TOKEN`). Perfil típico: Archivo Central. Para permisos de Administrador (catálogos, parámetros, plantillas, auditoría) hace falta un usuario con ese perfil en la base.

**Antes de empezar, confirme con desarrollo:**

- [ ] Frontend y backend están corriendo
- [ ] Migraciones **16** (anular documento) y **17** (catálogos, parámetros, plantillas, auditoría) aplicadas en Supabase
- [ ] El token de pruebas entra al módulo
- [ ] n8n F1–F5: ¿activos o se prueban a mano? (si no hay n8n, marque N/A los casos F1–F5)

---

## 3. Qué entra en esta ronda y qué no

### 3.1 Entrar (implementado — hay que verificar)

| Área | Tareas | Requisitos |
|---|---|---|
| Catálogos: dependencias, TRD, asuntos; importar Excel; inactivar | SGD-010 | RF-AC-001, 002, 003 |
| Catálogos: tipos, programas, ubicaciones | SGD-011 | RF-AC-004 |
| Usuarios, parámetros, plantillas | SGD-012 | RF-AC-005, 006 |
| Permisos, auditoría, anulación sin borrar | SGD-005, SGD-084 | RF-AC-023, 024 |
| Carga de un documento + duplicado (hash) | SGD-021, SGD-086 | RF-AC-008 |
| Transferencia **física** (FUID) | SGD-022 | RF-AC-009 |
| Bandejas Por clasificar / Clasificados + visor | SGD-030, SGD-085 | RF-AC-011 (parcial) |
| Comunicaciones: bandeja, detalle, remitir, devolver, responder, anular, correo adicional, historial | SGD-080, 040–042, 081–083 | RF-AC-015, 016, 017 (parcial 018/019) |
| Archivos locales (subir/ver por id) | SGD-008 | RN-AC-14 |

### 3.2 No entrar (aún no listo — no fallar el plan por esto)

| Área | Tarea | Motivo |
|---|---|---|
| Lotes reales, informe y reintento del Centro de cargas | SGD-020 | Avance e informe simulados |
| Transferencia **digital** (archivos por asunto) | SGD-023 | No sube los archivos |
| Guardar clasificación / reclasificar / TRD propuesto | SGD-030 | El botón Clasificar **no persiste** |
| Sugerencia con IA | SGD-031 | No iniciado |
| Árbol Archivo + búsqueda avanzada | SGD-032 | Datos de ejemplo / no hecho |
| Recordatorios diarios F4 | SGD-043 | Falta activar F4 |
| Importar Excel histórico 2024–2026 | SGD-044 | Solo pantalla |
| Historias académicas, carga masiva, PWA | SGD-050, 051, 060 | No iniciado |

### 3.3 Defectos ya reportados (confirmar, no reabrir como “nuevo” salvo que hayan cambiado)

| ID | Qué pasa | Resultado esperado de esta ronda |
|---|---|---|
| **SGD-087** | Crear **a mano** en Catálogos sale error | Confirmar si sigue fallando; anotar mensaje/JSON |
| **SGD-088** | En Por clasificar / Clasificados / Archivo solo el **botón** abre el visor | Confirmar; la fila completa no abre |
| **SGD-090** | Parámetros muestran textos tipo `RNF-AC-08`, `RF-AC-016` | Confirmar; debería ser una explicación en lenguaje de usuario |
| **SGD-089** | Errores: falta número+motivo unificado; formulario vs sistema | Anotar cómo se ve el error (¿genérico de HTTP?) |

---

## 4. Prueba automática de base (opcional, desarrollo)

Si el verificador tiene PostgreSQL local:

```bash
# desde database/
PG_BIN="/c/Program Files/PostgreSQL/18/bin" ./scripts/probar_local.sh
```

Esperado: migraciones + seed (dos veces) + `pruebas_reglas.sql` **sin fallos**, incluidos consecutivos concurrentes.

| ID | Resultado | Notas |
|---|---|---|
| TEST-BD-01 |  |  |

---

## 5. Casos de prueba (pantalla)

En cada caso: **pasos → esperado**. Rellene la tabla de la sección 8.

### A. Catálogos

**TEST-CAT-01** · RF-AC-001 · SGD-010  
Listar Dependencias, buscar y filtrar por estado.  
Esperado: lista con código, nombre, correo; no se borra ningún registro.

**TEST-CAT-02** · RF-AC-001 · SGD-010 · *defecto SGD-087*  
Crear una dependencia **a mano** (código y correo nuevos, ficticios).  
Esperado: se guarda y aparece en la lista.  
Si falla: **Falló** y pegue el mensaje (es SGD-087 si coincide).

**TEST-CAT-03** · RF-AC-001 · SGD-010  
Intentar crear/editar con **código o correo ya usado**.  
Esperado: rechazo; el campo repetido queda marcado; no se duplica.

**TEST-CAT-04** · RF-AC-001 · SGD-010  
Inactivar una dependencia: debe pedir **motivo**; no hay botón eliminar.  
Esperado: pasa a inactiva; el motivo queda; no desaparece de la base (sigue consultable con filtro inactivas).

**TEST-CAT-05** · RF-AC-002 · SGD-010  
Importar Excel de TRD (o CSV) con al menos una fila **válida** y una con **código duplicado**.  
Esperado: vista previa con error en la fila mala; al confirmar **solo** entran las válidas.

**TEST-CAT-06** · RF-AC-003 · SGD-010  
Crear el mismo nombre de asunto en **dos dependencias** distintas.  
Esperado: se permite. En **la misma** dependencia: rechazo.

**TEST-CAT-07** · RF-AC-004 · SGD-011  
Tipos documentales, Programas y Ubicaciones: crear (si SGD-087 no bloquea), editar, inactivar con motivo. Programas: importar Excel si hay plantilla.  
Esperado: no hay borrado físico; nombre único.

**TEST-CAT-08** · RF-AC-005 · SGD-012  
Catálogos › Usuarios: asignar perfil y dependencia (no se “crea” el usuario aquí: llega de NOVA).  
Esperado: no se muestran cédula, teléfono ni datos crudos de NOVA.

**TEST-CAT-09** · RF-AC-006 · SGD-012 · *defecto SGD-090*  
Catálogos › Parámetros: leer cada texto y cambiar un valor dentro de rango (ej. plazo) y uno **fuera** de rango.  
Esperado: el válido se guarda; el inválido se rechaza. Los textos **no** deben citar RNF/RF/RN (si los citan: Falló = SGD-090).

**TEST-CAT-10** · RF-AC-006 · SGD-012  
Administración › Plantillas de correo: abrir una, ver **vista previa** con datos de ejemplo, guardar (pide confirmación viendo la previa) y “restablecer original”.  
Esperado: se guarda; se puede volver al texto original. El siguiente correo real (si hay n8n) usaría la plantilla; si no hay n8n, N/A esa parte.

---

### B. Auditoría y anulación

**TEST-AUD-01** · RF-AC-023 · SGD-005  
Administración › Auditoría: filtrar por fecha, acción, recurso, resultado. Abrir un detalle.  
Esperado: se ven cambios y motivo; no hay editar/borrar registros de auditoría.

**TEST-AUD-02** · RF-AC-023 · SGD-005  
Con un usuario **sin** permiso de catálogos, intentar crear o cambiar un parámetro (o usar un token sin perfil Administrador).  
Esperado: denegado; el intento **queda en auditoría**. Si no hay segundo usuario: Bloqueado.

**TEST-ANU-01** · RF-AC-024 · SGD-084  
En un documento clasificado (o desde su ficha): **Anular documento** con motivo.  
Esperado: pide motivo; deja de verse en listas normales; **sigue existiendo** (filtro anulados o en base). Sin motivo no anula.

**TEST-ANU-02** · RF-AC-024 · SGD-080  
En una comunicación activa: Anular con motivo.  
Esperado: estado Anulada; no se borra; historial registra la anulación.

---

### C. Cargas y transferencias

**TEST-CAR-01** · RF-AC-008 · SGD-021  
Centro de cargas › documento individual: subir un PDF/imagen ficticio con dependencia y año.  
Esperado: queda registrado (por clasificar si faltan datos). Avisos de estado visibles (SGD-086).

**TEST-CAR-02** · RF-AC-008 · SGD-021  
Subir **el mismo archivo** otra vez al mismo expediente (misma dependencia + año + asunto si aplica).  
Esperado: duplicado rechazado (mensaje 409 o equivalente); no hay dos copias.

**TEST-CAR-03** · RF-AC-007 · SGD-020  
Lote con avance, informe descargable y reintento.  
Esperado en esta ronda: **N/A o Falló conocido** — el lote real no está; no bloquear el resto del plan.

**TEST-TRF-01** · RF-AC-009 · SGD-022  
Transferencias: nueva **física**, cargar FUID (Excel) con filas válidas.  
Esperado: se registra inventario por caja; estado coherente (en proceso / recibida).

**TEST-TRF-02** · RF-AC-009 · RN-AC-03 · SGD-022  
En 2026, inventario o transferencia del año **2025** (año actual − 1).  
Esperado: aviso y **no** se confirma (solo hasta año actual − 2).

**TEST-TRF-03** · RF-AC-010 · SGD-023  
Transferencia tipo **digital** con archivos por asunto.  
Esperado esta ronda: **N/A** (no implementado).

---

### D. Por clasificar, clasificados, visor, archivo

**TEST-CLA-01** · RF-AC-011 · SGD-030, SGD-085  
Por clasificar: lista real; abrir un ítem con el botón y ver el visor (PDF o imagen).  
Esperado: se ve el archivo o un aviso claro si **no está en este servidor** (no un error 500 ni la ruta del disco).

**TEST-CLA-02** · SGD-085  
Mismo visor en Clasificados.  
Esperado: igual que TEST-CLA-01.

**TEST-CLA-03** · RF-AC-011 · SGD-030  
Completar el formulario y pulsar Clasificar.  
Esperado según F-02: queda clasificado con expediente/TRD.  
**Hoy:** el guardado **no persiste** — marque Falló conocido y no lo trate como regresión nueva.

**TEST-CLA-04** · SGD-088  
En Por clasificar, Clasificados y Archivo: clic en la **fila/tarjeta** (fuera del botón).  
Esperado F-02/UX: abre la previsualización. **Hoy:** solo el botón — confirmar SGD-088.

---

### E. Comunicaciones (bandeja)

Hace falta n8n o correos ya cargados en la base. Si F1 está inactivo, use comunicaciones de prueba ya existentes.

**TEST-COM-01** · RF-AC-015 · SGD-040, SGD-080  
Bandeja por estados (Nueva, Remitida, Respondida, Devuelta, Cerrada, Anulada). Abrir un detalle a pantalla completa.  
Esperado: consecutivo `ENT-AAAA-NNNNNN` (o el que tenga la base); visor de adjuntos; historial.

**TEST-COM-02** · RF-AC-015 · RNF-AC-04 · SGD-040  
El mismo correo (mismo Message-ID) llega dos veces (F1 a mano o reproceso).  
Esperado: **una sola** comunicación. Sin n8n: N/A.

**TEST-COM-03** · RF-AC-016 · SGD-041  
Remitir a una dependencia con plazo (días hábiles).  
Esperado: pasa a Remitida; el correo (si F2/F5 corren) lleva `[SGD <consecutivo>]` en el asunto.

**TEST-COM-04** · RF-AC-016 · SGD-041  
Respuesta de la dependencia **sin** la etiqueta, con In-Reply-To del correo de remisión.  
Esperado: se asocia a la misma comunicación. Sin n8n: N/A.

**TEST-COM-05** · RF-AC-016 · SGD-083  
Dos respuestas de la misma dependencia (dos correos).  
Esperado: **no se pierde** el texto ni los adjuntos del primero; cada uno es un paso del historial.

**TEST-COM-06** · D-20 · SGD-081  
En una Nueva: **Responder directo** al remitente (sin remitir a dependencia).  
Esperado: se envía (si F3 está), se crea SAL y se cierra. Si aparece “datos no válidos”: Falló (anote mensaje).

**TEST-COM-07** · RF-AC-017 · SGD-042  
Flujo completo: remitida → respuesta dependencia → **Enviar respuesta** al remitente.  
Esperado: se crea SAL enlazada; la entrada queda **Cerrada**. Si el envío de correo falla, **no** debe cerrar (si puede simular fallo de F5).

**TEST-COM-08** · SGD-082  
En el historial, abrir un paso que envió o recibió correo.  
Esperado: se ve De, Para, asunto, cuerpo y adjuntos. Correos anteriores a la copia pueden mostrar aviso.

**TEST-COM-09** · SGD-083  
Correo adicional a **otra** dependencia activa (con correo oficial).  
Esperado: se envía o queda registrado; dependencias sin correo oficial no se pueden elegir.

**TEST-COM-10** · RF-AC-018 · SGD-043  
Recordatorio automático diario y resumen.  
Esperado esta ronda: **N/A** (F4 no activo). El recordatorio **manual** sí se puede probar si el botón está.

**TEST-COM-11** · RF-AC-018 · SGD-043  
Bandeja Correos sin asociar: asociar o crear comunicación (si hay ítems).  
Esperado: deja de estar “sin asociar”.

**TEST-COM-12** · RF-AC-019 · SGD-044  
Registro histórico: ver calendario/listado. Importar Excel 2024/2025/2026 dos veces.  
Esperado listado: OK si hay datos. Importar: **N/A** (no implementado).

---

### F. Archivos y errores

**TEST-ARC-01** · SGD-008  
Descargar o ver un adjunto por el visor.  
Esperado: llega el archivo; si no está en **este** equipo, mensaje claro (404), no la ruta del disco.

**TEST-ERR-01** · SGD-089  
Provocar un error de formulario (campo vacío o duplicado) y, si puede, un error de sistema.  
Esperado (regla nueva, aún no hecha): formulario = descripción; sistema = número + motivo.  
Hoy: anote qué muestra la pantalla (toast genérico vs texto del backend).

---

## 6. Comprobaciones cortas de pantalla (desktop)

Probar en escritorio. Si puede, repetir a ~375 px (móvil) los visores y la bandeja.

| ID | Qué mirar | OK / Falló |
|---|---|---|
| TEST-UI-01 | El módulo abre dentro del Panel de Área, menú lateral Archivo Central |  |
| TEST-UI-02 | Comunicaciones: detalle a página completa, volver funciona |  |
| TEST-UI-03 | Visor PDF / imagen / (si hay) Word o Excel |  |
| TEST-UI-04 | No hay botón “eliminar definitivamente” usable en producción |  |

---

## 7. Criterio para devolver el plan

La ronda **se puede cerrar** cuando:

1. Todos los casos de las secciones A–F están marcados (no en blanco), y  
2. Los **Falló** tienen nota (mensaje o captura), y  
3. Los defectos SGD-087, 088, 090 están confirmados o marcados OK si ya no ocurren, y  
4. Lo de la sección 3.2 no se usó como fallo del módulo entero.

Un **Falló** en un caso de 3.1 (salvo los defectos ya listados) impide pasar esa tarea a “hecha”.

---

## 8. Hoja de resultados (copie y llene)

**Verificador:** _________________  
**Fecha:** _________________  
**Ambiente:** frontend ___  backend ___  migraciones 16/17: sí / no  
**n8n F1–F5:** activo / inactivo / no hay  

| ID | Resultado | Evidencia breve (mensaje, consecutivo, captura) |
|---|---|---|
| TEST-BD-01 |  |  |
| TEST-CAT-01 |  |  |
| TEST-CAT-02 |  |  |
| TEST-CAT-03 |  |  |
| TEST-CAT-04 |  |  |
| TEST-CAT-05 |  |  |
| TEST-CAT-06 |  |  |
| TEST-CAT-07 |  |  |
| TEST-CAT-08 |  |  |
| TEST-CAT-09 |  |  |
| TEST-CAT-10 |  |  |
| TEST-AUD-01 |  |  |
| TEST-AUD-02 |  |  |
| TEST-ANU-01 |  |  |
| TEST-ANU-02 |  |  |
| TEST-CAR-01 |  |  |
| TEST-CAR-02 |  |  |
| TEST-CAR-03 |  |  |
| TEST-TRF-01 |  |  |
| TEST-TRF-02 |  |  |
| TEST-TRF-03 |  |  |
| TEST-CLA-01 |  |  |
| TEST-CLA-02 |  |  |
| TEST-CLA-03 |  |  |
| TEST-CLA-04 |  |  |
| TEST-COM-01 |  |  |
| TEST-COM-02 |  |  |
| TEST-COM-03 |  |  |
| TEST-COM-04 |  |  |
| TEST-COM-05 |  |  |
| TEST-COM-06 |  |  |
| TEST-COM-07 |  |  |
| TEST-COM-08 |  |  |
| TEST-COM-09 |  |  |
| TEST-COM-10 |  |  |
| TEST-COM-11 |  |  |
| TEST-COM-12 |  |  |
| TEST-ARC-01 |  |  |
| TEST-ERR-01 |  |  |
| TEST-UI-01 |  |  |
| TEST-UI-02 |  |  |
| TEST-UI-03 |  |  |
| TEST-UI-04 |  |  |

**Defectos nuevos** (que no sean SGD-087 a 090):

| # | Dónde | Qué pasó | Esperado |
|---|---|---|---|
| 1 |  |  |  |

**Conclusión del verificador:** listo para revisión / con fallos bloqueantes / ambiente incompleto.

---

## 9. Mapa requisito → caso (solo lo de esta ronda)

| Requisito | Caso F-05 | Tarea | ¿Se prueba ahora? |
|---|---|---|---|
| RF-AC-001 | TEST-CAT-01 a 04 | SGD-010 | Sí |
| RF-AC-002 | TEST-CAT-05 | SGD-010 | Sí |
| RF-AC-003 | TEST-CAT-06 | SGD-010 | Sí |
| RF-AC-004 | TEST-CAT-07 | SGD-011 | Sí |
| RF-AC-005 | TEST-CAT-08 | SGD-012 | Parcial (no hay login propio) |
| RF-AC-006 | TEST-CAT-09, 10 | SGD-012 | Sí (correo siguiente: si hay n8n) |
| RF-AC-007 | TEST-CAR-03 | SGD-020 | No (simulado) |
| RF-AC-008 | TEST-CAR-01, 02 | SGD-021 | Sí |
| RF-AC-009 | TEST-TRF-01, 02 | SGD-022 | Sí |
| RF-AC-010 | TEST-TRF-03 | SGD-023 | No |
| RF-AC-011 | TEST-CLA-01 a 04 | SGD-030, 085 | Parcial (no persiste clasificar) |
| RF-AC-012 | — | SGD-031 | No |
| RF-AC-013 / 014 | — | SGD-032 | No |
| RF-AC-015 | TEST-COM-01, 02 | SGD-040, 080 | Sí (F1 según n8n) |
| RF-AC-016 | TEST-COM-03 a 05, 09 | SGD-041, 083 | Sí |
| RF-AC-017 | TEST-COM-06, 07 | SGD-042, 081 | Sí |
| RF-AC-018 | TEST-COM-10, 11 | SGD-043 | Parcial (manual / sin asociar) |
| RF-AC-019 | TEST-COM-12 | SGD-044 | Solo consulta |
| RF-AC-020 a 022 | — | SGD-050–060 | No |
| RF-AC-023 | TEST-AUD-01, 02 | SGD-005 | Sí |
| RF-AC-024 | TEST-ANU-01, 02 | SGD-084, 005 | Sí |
