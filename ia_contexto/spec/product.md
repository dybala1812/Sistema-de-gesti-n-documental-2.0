# Producto — Sistema de Gestión Documental (SGD) · Módulo Archivo Central

Fuente: `ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx` — Especificación de requisitos del módulo Archivo Central, v1.1, 2026-10-07 (ISO/IEC/IEEE 29148). Si este archivo y la fuente difieren, manda la fuente; la diferencia se corrige aquí.

> ⚠️ El F-02 debe ser **firmado por el cliente (numeral 9)** antes de iniciar la construcción. Las maquetas de pantallas también deben validarse con la jefatura antes de desarrollar (§5.1).

Cliente: Archivo Central de la Universidad Autónoma (Uniautónoma del Cauca). Jefatura: Hoover. Proyecto de práctica profesional.

## Objetivo

Reemplazar los **Excel por año** y los **PDF mensuales por oficina** —y el circuito manual de recibir, escanear y remitir correos— con un único sistema donde se **registra, custodia y consulta** lo que llega al Archivo Central: un repositorio clasificado, auditable y conectado al correo institucional.

## Usuarios / roles

Los perfiles son **fijos** en esta versión (no hay pantalla para crear roles).

| Rol | Qué hace en el sistema | Permisos |
|---|---|---|
| **Archivo Central** (usuario principal) | Recibe transferencias, carga, clasifica y custodia documentos e historias; gestiona las comunicaciones por correo. | Acceso total al módulo, salvo usuarios y parámetros sensibles. |
| **Dependencia** | Oficina productora: transfiere cada año y responde las comunicaciones que se le remiten. | Transferir y consultar **solo lo de su dependencia**. |
| **Registro Académico** | Gestiona las historias de estudiantes **activos**. | Cargar y consultar historias activas. |
| **Secretaría General** | Consulta documentos institucionales, comunicaciones e historias. | Solo consulta. |
| **Administrador** | Configura catálogos, usuarios, parámetros y revisa la auditoría. | Catálogos, usuarios, parámetros y auditoría. |

## Incluye

- **Catálogos**: dependencias, TRD, asuntos por dependencia, tipos documentales, programas académicos, ubicaciones físicas (opcional), usuarios, parámetros y plantillas de correo.
- **Centro de cargas**: punto único para todas las cargas, con lotes, avance, duplicados e informe.
- **Transferencias documentales**: físicas (solo inventario FUID + acta) y digitales (inventario + archivos), con validación de la regla de 2 años.
- **Clasificación y archivo**: bandejas *Por clasificar* / *Clasificados*, árbol **Dependencia → Año → Asunto**, visor PDF, sugerencia opcional con IA.
- **Búsqueda avanzada** de documentos y comunicaciones.
- **Comunicaciones por correo**: recepción automática, remisión a dependencias, respuesta al remitente, recordatorios, correos sin asociar y registro histórico (importación de Excel 2024/2025/2026).
- **Historias académicas**: árbol **Estado → Año → Nivel → Programa → estudiante (alfabético)**, ficha del estudiante y carga masiva (~30.000 historias, años 70 a 2024).
- **App móvil (PWA)**: escaneo con la cámara y carga directa.
- **Control**: perfiles, auditoría inmutable y anulación sin borrado.

## No incluye

- Historias laborales (y el perfil Talento Humano) — eliminadas en v1.1.
- El archivo de gestión de cada oficina.
- La radicación del sistema que ya usa la universidad.
- Escaneo de transferencias físicas (solo se registra su inventario).
- Creación de roles personalizados.
- Borrado definitivo desde la aplicación.

Supuesto de partida: los documentos son **digitales desde 2020**; los anteriores se custodian en físico y se registran por su inventario.

## Restricciones

- **Tecnológicas**: PostgreSQL en **Supabase**; archivos **guardados localmente en carpetas**; la base guarda un **id** por archivo que lo referencia (con ruta relativa, hash y metadatos); **n8n** con acceso al buzón institucional y escritura directa en Supabase; frontend **React** + **PWA**.
- **Normativas**: Ley 594 de 2000 (Ley General de Archivos), Decreto 1080 de 2015, Ley 1581 de 2012 y Decreto 1377 de 2013 (datos personales). Calidad: ISO/IEC 25010.
- Sin borrado definitivo desde la aplicación. Perfiles fijos.
- Alcance académico sujeto al cronograma de la práctica profesional.

## Supuestos y dependencias del cliente

- El cliente entrega: TRD, asuntos por dependencia, correos oficiales de cada dependencia, un FUID de ejemplo y los Excel históricos.
- La universidad da acceso al buzón de Archivo Central (proveedor por confirmar: Google Workspace o Microsoft 365) y espacio de almacenamiento en su servidor.
- Las historias escaneadas se entregan organizadas por carpetas con una convención de nombres acordada.
- La sugerencia con IA depende de un servicio externo y es **opcional**.

## Glosario

| Término | Definición |
|---|---|
| Archivo de gestión | Archivo de cada oficina; los documentos permanecen allí **2 años**. |
| Archivo Central | Custodia lo transferido por las dependencias y las historias de estudiantes retirados y graduados. |
| Transferencia documental | Entrega anual de una dependencia, física (cajas) o digital (archivos), con inventario y acta. |
| FUID | Formato Único de Inventario Documental: Excel con cajas, carpetas, asuntos, fechas, folios y rangos. |
| TRD | Tabla de Retención Documental: series, subseries, tiempos de retención y disposición final. |
| Asunto | Término del cliente para la **serie documental** (actas, circulares, resoluciones…). Se define **por dependencia**. |
| Foliar / rotular | Numerar las hojas de una carpeta / identificar cajas y carpetas con su rótulo. |
| Historia académica | Expediente de un estudiante: activa (Registro Académico), retirado o graduado (Archivo Central). |
| Comunicación | Correo o documento recibido, enviado o interno, con consecutivo **ENT**, **SAL** o **INT**. |
| Lote de carga | Conjunto de archivos cargados en una operación, con su avance e informe. |
| Hash SHA-256 | Huella del archivo para detectar duplicados y verificar integridad. |
| Message-ID | Identificador único de un correo; evita registrarlo dos veces y asocia respuestas. |
| PWA | Aplicación web instalable en el celular con acceso a la cámara. |
| n8n | Herramienta de automatización que ejecuta los flujos de correo, cargas e IA. |

## Pantallas (validar maquetas antes de desarrollar)

Mockups interactivos: `ia_contexto/diseno/mockups_archivo_central_y_movil.html` — descripción pantalla por pantalla y diferencias con el F-02 en `ia_contexto/diseno/README.md`.

| Pantalla | Contenido |
|---|---|
| Inicio | Pendientes por clasificar, comunicaciones nuevas y vencidas, transferencias en proceso, dependencias que no han transferido este año. |
| Centro de cargas | Tarjetas por tipo de carga, asistente en 4 pasos (destino y datos → archivos → vista previa con validación → confirmación) y detalle de lote con avance e informe. |
| Transferencias | Lista por dependencia, año, tipo y estado; detalle con inventario por caja y acta adjunta. |
| Por clasificar / Clasificados | Lista con filtros; visor PDF junto al formulario (tipo, consecutivo, fecha, caja, carpeta, asunto). |
| Archivo | Árbol Dependencia → Año → Asunto con contadores, listado y visor. |
| Buscar | Filtros por año, mes, dependencia, tipo, asunto, consecutivo y persona. |
| Comunicaciones | Bandeja con pestañas por estado; detalle con línea de pasos e historial; ventanas Remitir y Responder; correos sin asociar; histórico en calendario. |
| Historias académicas | Árbol Estado → Año → Nivel → Programa; ficha del estudiante; carga masiva. |
| Catálogos | Lista con buscador, panel de edición, activar/inactivar, importar y exportar. |
| Auditoría | Tabla filtrable por usuario, acción, recurso y fecha. |
| App móvil | Inicio de sesión, escaneo multipágina, formulario y subida. |

## Entregas / sprints

Total estimado: **121 puntos en 18 historias** (ver `historias/archivo-central.md`). La distribución por sprint e integrante se define en el **F-04** (Bitácora de desarrollo).

| Sprint | Fechas | Objetivo |
|---|---|---|
| — | Por definir (F-04) | — |
