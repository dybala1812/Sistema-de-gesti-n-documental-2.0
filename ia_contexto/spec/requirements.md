# Requisitos — SGD · Módulo Archivo Central

Fuente: `ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx` (v1.1, 2026-10-07). Cada requisito conserva el ID de la fuente. Formato: `.agents/skills/project-manager/references/rf-for-ia.md`.
Los criterios Dado/Cuando/Entonces se derivan de los flujos principal y alternativo del F-02 y de los casos de prueba de su matriz de trazabilidad (§8). Lo marcado como *(pendiente)* depende de `decisiones.md`.

Perfiles: **AC** = Archivo Central · **DEP** = Dependencia · **RA** = Registro Académico · **SG** = Secretaría General · **ADM** = Administrador.

---

## Catálogos

## RF-AC-001

**Gestionar dependencias** · ADM · Alta · HU-AC-01

Datos: código (único), nombre, dependencia superior (opcional), responsable, correo oficial (único), estado (activa/inactiva).
Es el primer nivel del árbol del archivo; su correo oficial sirve para remitir comunicaciones y reconocer respuestas.

- Dado un ADM en Catálogos > Dependencias, cuando guarda una dependencia con código y correo nuevos, entonces queda disponible para transferencias, asuntos, clasificación y remisión.
- Dado que ya existe el código o el correo, cuando intenta guardar, entonces el sistema rechaza y señala el campo repetido.
- Dado un Excel de dependencias, cuando lo importa, entonces ve una vista previa con los errores antes de confirmar.
- Dado una dependencia con documentos o comunicaciones, cuando intenta eliminarla, entonces solo puede inactivarla.

Reglas: RN-AC-01, RN-AC-12

## RF-AC-002

**Gestionar la Tabla de Retención Documental (TRD)** · ADM / AC · Alta · HU-AC-01

Datos: código TRD (identificador de clasificación), nombre, descripción, tipo (serie/subserie, con serie padre), años en archivo de gestión (2), años en archivo central, disposición final, estado.

- Dado un usuario con permiso de catálogos, cuando crea o edita una serie/subserie, entonces se guarda y el cambio queda en la auditoría.
- Dado un Excel de TRD con códigos duplicados, cuando lo importa, entonces el sistema reporta los duplicados y no los inserta.
- Dado una serie con documentos asociados, cuando intenta eliminarla, entonces solo puede inactivarla.

Reglas: RN-AC-02, RN-AC-03, RN-AC-12

## RF-AC-003

**Gestionar asuntos por dependencia** · AC / ADM · Alta · HU-AC-01

Datos: dependencia, nombre, código TRD, descripción, estado. Depende de RF-AC-001 y RF-AC-002.
"Asunto" = serie documental en lenguaje del cliente (actas, circulares, resoluciones, convenios, comprobantes de egreso…).

- Dado la dependencia A con el asunto "Actas", cuando se crea "Actas" en la dependencia B, entonces se acepta.
- Dado la dependencia A con el asunto "Actas", cuando se crea otro "Actas" en A, entonces se rechaza.
- Dado un asunto con documentos, cuando intenta eliminarlo, entonces solo puede inactivarlo.
- La descripción del asunto alimenta la sugerencia con IA (RF-AC-012).

Reglas: RN-AC-01, RN-AC-02

## RF-AC-004

**Gestionar tipos documentales, programas académicos y ubicaciones físicas** · AC / ADM · Media · HU-AC-02

Datos: tipos documentales (acta, memorando, circular, resolución, comprobante de egreso…); programas con nivel (pregrado/posgrado); ubicaciones físicas opcionales (bodega, estante, módulo).

- Dado cualquiera de estos catálogos, cuando el usuario crea o edita, entonces el sistema valida nombre único y audita.
- Dado un tipo documental en uso, cuando se inactiva, entonces no se elimina y deja de ofrecerse en formularios nuevos.
- Programas académicos admite importación desde Excel.
- El catálogo de ubicaciones físicas solo se activa si el cliente lo confirma *(pendiente)*.

## RF-AC-005

**Gestionar usuarios y perfiles** · ADM · Alta · HU-AC-03

Datos: nombre, correo, dependencia, perfil (uno de los 5 fijos), estado.

- Dado un ADM, cuando crea o edita un usuario, entonces se guarda con auditoría.
- Dado un usuario inactivo, cuando intenta iniciar sesión, entonces se le deniega y su historial se conserva.
- No existe pantalla para crear roles.

Reglas: RN-AC-12

## RF-AC-006

**Gestionar parámetros y plantillas de correo** · ADM / AC · Media · HU-AC-03

Parámetros: años mínimos antes de transferir (2), tamaño máximo por archivo (50 MB, tentativo), formatos permitidos, plazo de respuesta de dependencias, frecuencia de recordatorios (2 días hábiles), máximo de recordatorios antes de escalar (3), umbral de confianza de la IA.
Plantillas: acuse de recibo, remisión, devolución, respuesta, recordatorio, resumen diario. Campos variables: nombre, consecutivo, asunto, plazo.

- Dado un parámetro, cuando se guarda un valor fuera de rango o vacío, entonces se rechaza.
- Dado una plantilla editada, cuando se guarda, entonces se muestra vista previa antes y el siguiente correo enviado usa el texto nuevo.
- Todo cambio queda auditado.

---

## Cargas y transferencias

## RF-AC-007

**Centro de cargas y seguimiento de lotes** · AC / DEP / RA · Alta · HU-AC-04

Tipos de carga: documento individual, transferencia física, transferencia digital, historias académicas, registro histórico, app móvil. Cada carga es un **lote** con avance, contadores e informe.
Asistente de 4 pasos: destino y datos → archivos → vista previa con validación → confirmación.

- Dado un lote con un archivo válido, uno duplicado y uno inválido, cuando termina, entonces el informe muestra 1 aceptado, 1 duplicado y 1 error con su motivo.
- Dado un archivo con error, cuando se procesa el lote, entonces el resto del lote continúa.
- Dado un lote con fallidos, cuando el usuario pulsa reintentar, entonces solo se reprocesan los fallidos.
- El informe del lote se puede descargar. El lote queda auditado.

## RF-AC-008

**Cargar un documento individual** · AC · Alta · HU-AC-05

Datos: dependencia y año (obligatorios); asunto, tipo, consecutivo, fecha, caja y carpeta (opcionales). Archivo PDF o imagen.

- Dado un archivo con formato y tamaño permitidos, cuando se carga, entonces se calcula SHA-256, se guarda en su carpeta local, se crea su registro en `archivo` (id) y el documento queda enlazado a ese id.
- Dado el mismo PDF cargado dos veces en el mismo expediente, cuando se carga la segunda vez, entonces se rechaza indicando el documento existente.
- Dado que faltan datos de clasificación, cuando se guarda, entonces el documento queda "por clasificar"; si están completos, "clasificado".

Reglas: RN-AC-11, RN-AC-14

## RF-AC-009

**Registrar una transferencia documental física** · AC · Alta · HU-AC-06

Datos: dependencia, año, tipo "física", funcionario que entrega, acta/FUID (Excel o PDF). Detalle por caja: carpeta o tomo, asunto, fecha inicial y final, folios, rango de consecutivos.
**No se escanean** los documentos.

- Dado un FUID en Excel, cuando se adjunta, entonces el sistema lo lee y muestra el inventario por caja.
- Dado un FUID con columnas obligatorias faltantes o fechas inválidas, cuando se valida, entonces las filas con error se muestran para que la dependencia corrija.
- Dado el año 2026, cuando se registra una transferencia del año 2025, entonces el sistema avisa y no permite confirmar (máximo permitido: 2024).
- Dado un inventario verificado contra las cajas, cuando AC marca "recibida", entonces la transferencia queda en estado "recibida" con su inventario y acta.

Reglas: RN-AC-03, RN-AC-04, RN-AC-05

## RF-AC-010

**Registrar una transferencia documental digital** · DEP / AC · Alta · HU-AC-07

Datos: igual que RF-AC-009 con tipo "digital", más los archivos agrupados por asunto (documentos desde 2020).

- Dado una transferencia digital, cuando se cargan archivos indicando el asunto de cada grupo, entonces se calcula hash, se descartan duplicados y cada archivo queda asociado a dependencia, año y asunto.
- Dado una transferencia incompleta, cuando el usuario vuelve en otra sesión, entonces puede continuarla.
- Dado que la revisión IA detecta documentos que parecen de otro asunto, entonces solo avisa (no reclasifica).
- Dado que AC revisó, cuando marca "recibida", entonces la transferencia cambia a "recibida".

Reglas: RN-AC-03, RN-AC-05, RN-AC-11, RN-AC-13

---

## Clasificación, archivo y búsqueda

## RF-AC-011

**Clasificar documentos** · AC · Alta · HU-AC-08

Datos: tipo, consecutivo, fecha, caja, carpeta, asunto y código TRD.

- Dado la bandeja "Por clasificar" filtrada por dependencia, año u origen, cuando se abre un documento, entonces se ve el PDF a un lado y el formulario al otro.
- Dado un asunto elegido, entonces el sistema propone su código TRD.
- Dado un documento con datos completos, cuando se guarda, entonces pasa a "clasificado", queda en su expediente y se audita.
- Dado un documento clasificado, cuando se reclasifica, entonces queda registro del cambio (valores previos y nuevos).
- Dado que el asunto no existe, el usuario con permiso puede crearlo (RF-AC-003).

Reglas: RN-AC-01, RN-AC-02

## RF-AC-012

**Sugerir clasificación con IA** · AC · Baja · HU-AC-08

- Dado un documento sin clasificar o un correo nuevo, cuando se pide "Sugerir con IA", entonces el flujo F11 devuelve asunto (o dependencia, para comunicaciones), confianza y justificación, precargados en el formulario.
- Dado una sugerencia, cuando el usuario la acepta, modifica o descarta, entonces la decisión queda auditada y la clasificación cambia **solo** con esa confirmación.
- Dado que el servicio IA falla o la confianza es menor al umbral, entonces se clasifica manualmente sin bloquear.
- Dado una historia académica, entonces la opción IA no está disponible.

Reglas: RN-AC-13

## RF-AC-013

**Navegar el archivo y consultar documentos** · AC / DEP / SG · Alta · HU-AC-09

- Dado el árbol Dependencia → Año → Asunto, cada nodo muestra su cantidad de documentos.
- Dado un documento, cuando se abre, entonces se ve en el visor junto a tipo, consecutivo, fecha, caja, carpeta y TRD.
- Dado un usuario DEP, entonces solo ve las carpetas de su dependencia.
- Dado un perfil con permiso de descarga, cuando descarga, entonces queda auditado *(qué perfiles descargan: pendiente)*.

Reglas: RN-AC-01

## RF-AC-014

**Búsqueda avanzada** · AC / DEP / SG · Alta · HU-AC-09

Criterios: año, mes, dependencia, tipo (entrada/salida/interno), asunto, consecutivo, persona, código TRD. Resultados paginados (20 por página) con vista previa.

- Dado el texto "385" o "385 del 29 de febrero", cuando se busca por consecutivo, entonces encuentra el registro 385 (y la fecha si se indica).
- Dado una búsqueda por persona, entonces devuelve documentos y comunicaciones asociados a ella, filtrados por los permisos del usuario.
- Dado una búsqueda sin resultados, entonces se sugiere ampliar filtros.
- Las consultas a historias académicas quedan auditadas.

---

## Comunicaciones por correo

Estados (RN-AC-09): **Nueva → Remitida → Respondida por dependencia → (Devuelta ↺) → Cerrada**; **Anulada** desde cualquier estado activo.

## RF-AC-015

**Recibir y registrar comunicaciones por correo** · Sistema (F1) / AC · Alta · HU-AC-10

- Dado el buzón conectado, el flujo F1 lo revisa cada pocos minutos y el correo aparece en la bandeja en ≤ 5 min.
- Dado una respuesta automática, un rebote o un Message-ID ya procesado, entonces se descarta.
- Dado un correo nuevo, entonces se crea una comunicación de entrada `ENT-AAAA-NNNNNN`, se guardan sus adjuntos, queda en "Nueva" y se envía acuse de recibo al remitente con su consecutivo.
- Dado el mismo correo leído dos veces, entonces existe una sola comunicación.
- Dado que el correo es respuesta de una dependencia, entonces se aplica RF-AC-016; si no puede asociarse, va a "Correos sin asociar".
- El correo no se marca como leído hasta quedar registrado.

Reglas: RN-AC-08, RN-AC-09

## RF-AC-016

**Remitir a una dependencia y recibir su respuesta** · AC / Sistema (F2, F1) · Alta · HU-AC-11

- Dado una comunicación "Nueva" y una dependencia con correo oficial, cuando AC pulsa "Remitir" (dependencia, mensaje, adjuntos, plazo), entonces se envía con `[SGD <consecutivo>]` en el asunto y pasa a "Remitida".
- Dado que la dependencia responde, cuando F1 reconoce la etiqueta, entonces guarda respuesta y adjuntos, pasa a "Respondida por dependencia" y avisa a AC.
- Dado que la dependencia borró la etiqueta, entonces la respuesta se asocia por el encabezado `In-Reply-To`.
- Dado una respuesta incompleta, cuando AC pulsa "Devolver", entonces se envía con la plantilla de devolución y pasa a "Devuelta".

Reglas: RN-AC-09

## RF-AC-017

**Responder al remitente** · AC / Sistema (F3) · Alta · HU-AC-12

- Dado una comunicación "Respondida por dependencia", cuando AC pulsa "Enviar respuesta", entonces se precargan destinatario, plantilla y adjuntos de la dependencia.
- Dado el envío exitoso, entonces se crea la salida `SAL-AAAA-NNNNNN` enlazada a la entrada y la entrada pasa a "Cerrada".
- Dado un envío fallido, entonces el estado no cambia y se permite reintentar.
- Vincular la respuesta a la historia académica del estudiante: *(pendiente)*.

Reglas: RN-AC-08, RN-AC-09

## RF-AC-018

**Recordatorios y correos sin asociar** · Sistema (F4) / AC · Media · HU-AC-13

- Dado un día hábil, el sistema busca comunicaciones "Remitida" o "Devuelta" vencidas.
- Dado una dependencia con 5 comunicaciones vencidas, entonces recibe **un solo** correo con la lista.
- Dado una comunicación recordada, no se vuelve a recordar antes de 2 días hábiles; tras el 3.er recordatorio se marca para escalar (valores configurables, RF-AC-006).
- AC recibe un resumen diario de nuevas, vencidas y por escalar.
- Dado un correo en "Correos sin asociar", AC lo asocia a una comunicación existente o lo crea como nueva.
- Cada recordatorio queda en el historial de la comunicación.

## RF-AC-019

**Registro histórico de comunicaciones** · AC / SG · Alta · HU-AC-14

- Dado Comunicaciones > Histórico, el usuario elige año y mes en un calendario y filtra por recibidas, enviadas o internas.
- Dado un Excel histórico ("Autónoma 2024/2025/2026"), cuando lo importa, mapea columnas y confirma la vista previa, entonces se crean comunicaciones **cerradas** con consecutivo adaptado al formato del sistema y el número original conservado.
- Dado filas con consecutivo repetido en el mismo año, entonces se marcan para revisión.
- Dado el mismo Excel importado dos veces, entonces no se duplica nada.

Reglas: RN-AC-08, RN-AC-10

---

## Historias académicas

## RF-AC-020

**Gestionar historias académicas** · AC / RA / SG · Alta · HU-AC-15

Árbol: Estado (Retirados / Graduados) → Año → Nivel (Pregrado / Posgrado) → Programa → estudiantes en orden alfabético. Ficha: datos básicos, estado de la historia, documentos con visor.

- Dado un usuario, cuando busca por nombre o documento, entonces abre la ficha del estudiante.
- Dado un usuario RA, entonces solo ve y carga historias **activas** (no ve retirados ni graduados).
- Dado que un estudiante se gradúa o retira, cuando se cambia el estado, entonces la historia pasa a custodia de AC.
- Cada consulta queda auditada. La IA no aplica a historias.

Reglas: RN-AC-06, RN-AC-07, RN-AC-13

## RF-AC-021

**Carga masiva de historias académicas** · AC / RA · Alta · HU-AC-16

Volumen: ~30.000 historias (años 70 a 2024).

- Dado un destino en el árbol (estado, año, nivel, programa) o una carpeta con esa estructura, cuando se sube, entonces el sistema identifica al estudiante por el nombre del archivo *(convención: pendiente)* y muestra vista previa.
- Dado la confirmación, se procesa por lotes con avance y al final se entrega resumen de cargados, duplicados y errores.
- Dado un estudiante que ya tiene historia, entonces el documento se agrega a ella.
- La carga se puede pausar y retomar. Los estudiantes quedan ordenados alfabéticamente.

Reglas: RN-AC-07, RN-AC-11

---

## App móvil

## RF-AC-022

**Escanear y cargar desde el celular (PWA)** · AC · Media · HU-AC-17

- Dado un usuario con sesión en la PWA, cuando escanea una o varias páginas, entonces hay recorte automático y vista previa.
- Dado el formulario (dependencia, año, asunto, tipo, consecutivo, fecha, caja, carpeta), cuando pulsa "Subir", entonces se procesa como RF-AC-008.
- Dado que se pierde la conexión, entonces la app avisa y permite reintentar.
- Dado que faltan datos, entonces el documento queda "por clasificar".

---

## Control

## RF-AC-023

**Controlar acceso y registrar auditoría** · Sistema / ADM · Alta · HU-AC-18

- Dado un inicio de sesión, el sistema determina perfil y dependencia.
- Dado cualquier acción, se valida el permiso sobre la función **y** el recurso (backend, no solo UI).
- Dado una acción relevante, se registra usuario, acción, recurso, fecha y valores previos y nuevos.
- Dado un intento sin permiso, entonces se deniega y se audita.
- La auditoría no se puede editar ni borrar. El ADM la consulta con filtros.

Reglas: RN-AC-12

## RF-AC-024

**Anular sin borrar** · AC · Media · HU-AC-18

Aplica a documentos, comunicaciones y lotes.

- Dado un registro, cuando AC elige "Anular", indica motivo y confirma, entonces pasa a "Anulado" y se oculta de las listas normales.
- Dado un registro anulado, entonces sigue en la base y se consulta con un filtro específico.
- No existe borrado definitivo desde la interfaz.

Reglas: RN-AC-12

---

## Requisitos no funcionales

ISO/IEC 25010.

| ID | Característica | Requisito | Medida / criterio |
|---|---|---|---|
| RNF-AC-01 | Rendimiento | Búsquedas y listados rápidos con miles de registros. | < 3 s en búsquedas paginadas (20/página) con 50.000 documentos (prueba de carga; volumen tentativo). |
| RNF-AC-02 | Seguridad y privacidad | Proteger datos personales (Ley 1581); HTTPS; archivos no públicos. | 100 % de accesos no autorizados denegados y auditados; descarga solo con sesión o enlace temporal. |
| RNF-AC-03 | Integridad | Cada archivo se verifica y no se duplica. | SHA-256 por archivo; restricción única (expediente, hash); verificación semanal de hashes. |
| RNF-AC-04 | Confiabilidad del correo | Ningún correo se pierde ni se registra dos veces. | Message-ID único por comunicación; no marcar leído hasta registrar; 0 duplicados en prueba de reprocesamiento. |
| RNF-AC-05 | Oportunidad | Los correos aparecen pronto en la bandeja. | Registro en ≤ 5 min desde la llegada al buzón. |
| RNF-AC-06 | Capacidad y respaldo | Almacenamiento para la migración de historias, respaldado. | ~30.000 historias (~600 GB, por confirmar); respaldo diario de BD y archivos; restauración probada. |
| RNF-AC-07 | Usabilidad | Cargar y clasificar sin capacitación extensa. | Carga + clasificación de un documento < 3 min con un usuario real. |
| RNF-AC-08 | Compatibilidad | Formatos de digitalización y móvil. | PDF, JPG, PNG hasta 50 MB (tentativo); .xlsx para inventarios; Chrome/Edge escritorio, Chrome/Safari móvil. |
| RNF-AC-09 | Mantenibilidad | Módulo y flujos separados y documentados. | Módulo propio en backend y frontend; flujos n8n documentados; cobertura ≥ 60 % en consecutivos, estados y permisos. |
| RNF-AC-10 | Confiabilidad de la IA | La IA solo sugiere. | 100 % de sugerencias requieren confirmación humana y quedan auditadas. |
