# Decisiones y preguntas abiertas — SGD · Módulo Archivo Central

Las decisiones **Tomada** son vinculantes. Las **Propuesta** esperan aprobación antes de implementarse. Las **Por decidir** no se implementan por suposición. Registrar cada cambio con fecha.

## Decisiones

| ID | Decisión | Estado | Fecha | Fuente |
|---|---|---|---|---|
| D-01 | Base de datos: **PostgreSQL en Supabase**. | Tomada | 2026-10-07 | F-02 §2.1, §2.4 |
| D-02 | Archivos **guardados localmente en carpetas**; en BD cada archivo se registra con un **id** que lo referencia (tabla `archivo`: id, ruta relativa, nombre original, hash SHA-256, tamaño, tipo). Documentos y adjuntos apuntan a `archivo_id`. No se guardan binarios en la BD ni en Supabase Storage. | Tomada | 2026-10-07 | F-02 RN-AC-14 + usuario |
| D-03 | **n8n** ejecuta los flujos de correo, cargas e IA (F1–F11) y **escribe directamente en Supabase**; envía archivos al backend por HTTP (`POST /api/archivos`, solo el backend escribe en carpetas y en la tabla `archivo`) y recibe el **id** del archivo; con ese id escribe las demás tablas. Contrato en `backned_sistema_gestion_documental/n8n/TABLAS_N8N.md`. | Tomada | 2026-10-07 | F-02 §2.1, §5.2 |
| D-04 | Consecutivos generados por **función atómica de la BD**, por tipo (ENT/SAL/INT) y año. | Tomada | 2026-10-07 | F-02 RN-AC-08 |
| D-05 | **Perfiles fijos** (AC, DEP, RA, SG, ADM); sin pantalla de roles. | Tomada | 2026-10 | F-02 RF-AC-005 |
| D-06 | **Sin borrado físico**: solo anulación/inactivación con motivo y auditoría inmutable. | Tomada | 2026-10-07 | F-02 RN-AC-12 |
| D-07 | La **IA es opcional y solo sugiere**; nunca aplica a historias académicas. | Tomada | 2026-10 | F-02 RN-AC-13 |
| D-08 | Se eliminan **historias laborales** y el perfil Talento Humano del alcance. | Tomada | 2026-10-07 | F-02 v1.1 §10 |
| D-09 | Frontend en **React** + **PWA** para escaneo móvil. | Tomada | 2026-10-07 | F-02 §2.4 |
| D-10 | Paleta institucional obligatoria (`navy`, `orange`, `gold`, `beige`…). Ver `.claude/skills/frontend/color-palette.md`. | Tomada | 2026-10-07 | Usuario |
| D-11 | Prefijo de tareas del tablero: **`SGD`** (`SGD-001`…). | Propuesta | 2026-10-07 | Equipo |
| D-13 | **Sin login propio.** El usuario llega autenticado desde NOVA; el backend valida su token llamando a `GET /api/users/perfil/` de NOVA y sincroniza una copia en la tabla `usuario` (`fn_sincronizar_usuario_nova`). El perfil del módulo lo asigna un Administrador. | Tomada | 2026-10-07 | Usuario |
| D-14 | Base de datos implementada en `backned_sistema_gestion_documental/supabase/` (6 migraciones, seeds y pruebas). | Tomada | 2026-10-07 | Equipo |
| D-15 | **n8n solo maneja la Bandeja de comunicaciones** (F1 correo entrante, F2 remitir, F3 responder, F4 recordatorios, F5 envío, F6 errores). Cargas, transferencias/FUID, historias, importación del histórico e IA los hace el backend, no n8n. Los adjuntos de correo se suben al backend (`POST /api/archivos`); las tablas de comunicaciones se escriben directo en Supabase. | Tomada | 2026-10-07 | Usuario |
| D-16 | El módulo Archivo Central se construye **dentro del Panel de Área de NOVA** (`NOVA_FT/src/app/pages/tickets/AreaDashboard.tsx`), como un módulo más de la barra lateral (mismo modelo que Inventario). Resuelve P-12. | Tomada | 2026-10-07 | Usuario |
| D-17 | Las pantallas del módulo usan los **colores de NOVA** (app madre: Tailwind gris/blanco, navy `#1e3a5f`, naranja como acento del módulo); los mockups solo dan la distribución. Prevalece sobre D-10 dentro de NOVA. | Tomada | 2026-10-07 | Usuario |
| D-18 | Las comunicaciones nuevas que llegan por correo las crea n8n llamando al backend: **`POST /api/n8n/comunicaciones`** (token de servicio `N8N_SERVICE_TOKEN`), que registra comunicación + adjuntos en una transacción (`fn_registrar_comunicacion_n8n`). Precisa D-03/D-15 para esta operación. | Tomada | 2026-10-07 | Usuario |
| D-19 | **n8n habla solo con el backend**: las 19 operaciones de datos de los flujos F1–F6 pasan por `POST /api/n8n/*` (token `N8N_SERVICE_TOKEN`), que llaman a las funciones SQL `n8n_*` (migración 09). Solo quedan en el nodo Supabase 4 lecturas simples (dependencias activas, evento de acuse, plantilla de correo, parámetro del buzón). Reemplaza la escritura directa de D-03/D-15. Contrato: `database/n8n/APIs_backend_n8n.md`. | Tomada | 2026-10-07 | Usuario |
| D-20 | **Respuesta directa sin dependencia**: cuando una comunicación de entrada no requiere atención de una dependencia, Archivo Central puede responder directamente al remitente. Esto genera una excepción a RN-AC-09 permitiendo la transición `nueva → respondida_dependencia → cerrada` en una sola acción, disparando F3 sin modificar sus nodos. | Tomada | 2026-10-11 | Usuario |
| D-12 | Las respuestas de dependencias se asocian por la etiqueta `[SGD <consecutivo>]` en el asunto y, si falta, por `In-Reply-To`. | Tomada | 2026-10-07 | F-02 RF-AC-016 |
| D-21 | **Contrato de errores JSON.** Toda respuesta de error del backend es JSON con el **número del error** y el **motivo** (por qué sale). Distinción: (1) **error de sistema** (fallo interno, BD, generación de consecutivo): incluye número de error + motivo; el **consecutivo** (`ENT\|SAL\|INT-AAAA-NNNNNN`) solo se informa si el fallo es de sistema y el consecutivo ya existía o el error es del contador. (2) **error de formulario** (validación, campo faltante, duplicado, permiso): JSON con **descripción** clara para el usuario (`error`, `campo` si aplica); **no** se reserva ni se muestra un consecutivo. Implementación: SGD-089. | Tomada | 2026-10-27 | Usuario |
| D-22 | **Misma ubicación física en todas las pantallas de Archivo Central.** Siempre **Caja + Carpeta** (en ese orden, mismas etiquetas y ejemplos; componente `UbicacionFisica.tsx`). **Bodega · Estante · Módulo** es un bloque **opcional** que sale del catálogo "Ubicaciones físicas" y solo aparece si hay ubicaciones activas, así sirve mientras P-08 siga abierta. Lectura: "Caja 12 · Carpeta 3 (B1 · Estante 4 · Módulo 2)". En la transferencia la caja y la carpeta van por fila del FUID y la bodega es de toda la entrega. | Tomada | 2026-10-29 | Usuario |

## Preguntas abiertas (para el cliente / usuario)

| ID | Pregunta | Afecta | Responsable |
|---|---|---|---|
| P-01 | ¿El circuito de comunicaciones por correo entra en este proyecto o **duplica el sistema de radicación** existente? | RF-AC-015 a 019 | Jefatura (Hoover) |
| P-02 | ¿Proveedor del buzón institucional: **Google Workspace o Microsoft 365**? | F1–F5, RF-AC-015 | Universidad / TI |
| P-03 | Orden exacto de las carpetas de historias (Estado, Año, Nivel, Programa) y **convención de nombres** de archivo para identificar al estudiante. | RF-AC-020, 021 | Cliente |
| P-04 | **Plantilla oficial del FUID** (columnas obligatorias). | RF-AC-009, 010 | Cliente |
| P-05 | Espacio de almacenamiento para ~30.000 historias (~600 GB estimado) y política de respaldo en el servidor. | RNF-AC-06 | Universidad / TI |
| P-06 | ¿El sistema debe **generar rótulos** de caja y carpeta? | RF-AC-009 | Cliente |
| P-07 | ¿La respuesta al estudiante se **vincula a su historia académica**? | RF-AC-017, 020 | Cliente |
| P-08 | ¿Se activa el catálogo de **ubicaciones físicas** (bodega, estante, módulo)? | RF-AC-004 | Cliente |
| P-09 | ¿Qué perfiles pueden **descargar** archivos (vs. solo visualizar)? | RF-AC-013, RNF-AC-02 | Cliente |
| P-10 | Definición de **"expediente"** para la regla de duplicados: ¿Dependencia+Año+Asunto para documentos y la historia del estudiante para historias? | RN-AC-11, RNF-AC-03 | Equipo + cliente |
| P-11 | **Tecnología del backend** de la aplicación: ¿Django (como el backend actual de NOVA), Node, o solo Supabase (RLS + Edge Functions) + n8n? | Arquitectura completa | Equipo |
| P-12 | ~~¿Dentro de NOVA o independiente?~~ → resuelta por D-16 (dentro del Panel de Área). | — | — |
| P-13 | **Servicio de IA** a usar (proveedor, costo, tratamiento de datos personales al enviar contenido a un tercero). | RF-AC-012, Ley 1581 | Equipo + cliente |
| P-14 | Valores definitivos: tamaño máximo por archivo (50 MB tentativo), plazo de respuesta de dependencias, umbral IA, volumen de documentos (50.000 tentativo). | RF-AC-006, RNF-AC-01, 08 | Cliente |
| P-15 | Calendario de **días hábiles** (festivos de Colombia) para recordatorios. | RF-AC-018 | Equipo |
| P-17 | ¿El consecutivo de comunicaciones es `2026-CR-NNNNN` (mockup) o `ENT/SAL/INT-AAAA-NNNNNN` (F-02)? | RN-AC-08, RF-AC-015–017 | Cliente |
| P-18 | ¿Una transferencia puede ser **física y digital** a la vez (como en el mockup)? | RF-AC-009, 010 | Cliente |
| P-16 | ~~Autenticación~~ → resuelta por D-13 (token de NOVA). Pendiente: ¿la app móvil (PWA) también se abre desde NOVA o necesita su propio inicio de sesión contra NOVA? | RF-AC-022 | Equipo |
| P-19 | ¿El backend del módulo podrá llamar a `GET /api/users/perfil/` de NOVA desde el servidor (red/CORS/limites)? ¿O NOVA puede darnos un endpoint SSO como el de UniDoc (`/api/users/unidoc-sso/`)? | D-13 | Equipo NOVA / TI |

## Inconsistencias detectadas

| ID | Dónde | Descripción | Propuesta |
|---|---|---|---|
| I-01 | `NOVA_FT/README.md` vs. F-02 §2.1 | NOVA usa backend **Django REST**; el F-02 describe Supabase + n8n con escritura directa y no nombra framework de backend. | Resolver con P-11 antes de crear `backned_sistema_gestion_documental/`. |
| I-02 | Nombre de carpeta | `backned_sistema_gestion_documental` tiene un error tipográfico ("backned"). | Renombrar a `backend_...` antes de que haya código (decisión del equipo). |
| I-03 | `NOVA_FT/package.json` vs. `NOVA_FT/README.md` | package.json declara React 18.3.1 (peer); el README dice React 19. | Verificar la versión instalada y corregir el README. |
| I-04 | `NOVA_FT/src/styles/theme.css` vs. paleta institucional | El tema usa `#ff9800`, `#ffc107`, `#f8f9fa` en lugar de `orange #e8740e`, `gold #c89b14`, `beige #f3ede1`. | Alinear el tema al tocar la UI del módulo. |
| I-05 | F-02 RF-AC-012 vs. RF-AC-010 | La IA "revisa" transferencias digitales (RF-AC-010) pero RF-AC-012 la define para documentos sin clasificar y correos. | Tratar la revisión de transferencias como aviso (no sugerencia aplicable); confirmar alcance. |
| I-06 | F-02 RF-AC-018 | "Por escalar" aparece como resultado, pero no es un estado de RN-AC-09. | Modelarlo como marca/bandera, no como estado. |
| I-07 | F-02 §5.2 vs. D-02/D-03 | El F-02 dice que n8n "recibe la ruta" del archivo y que la BD guarda la ruta; el usuario decidió (2026-10-07) que cada archivo se referencia por un **id** en la BD. | Actualizar el F-02 en su próxima versión (control de cambios §10). |
| I-08 | Mockups (Bandeja, Correos sin asociar) vs. RN-AC-08, RF-AC-016 | Consecutivo `2026-CR-01377` y etiqueta `[2026-CR-01377]` vs. `ENT/SAL/INT-AAAA-NNNNNN` y `[SGD consecutivo]`. | Decidir un único formato con el cliente y actualizar F-02 o mockups. |
| I-09 | Mockup Auditoría | Muestra "Consultó historia laboral" y usuario de Talento Humano; historias laborales fueron excluidas en v1.1. | Quitar del mockup. |
| I-10 | Mockup Catálogos vs. RN-AC-12 | Dice "activar o inactivar y eliminar". | Solo inactivar; quitar "eliminar". |
| I-11 | Mockup Auditoría ("Imprimió rótulos") vs. P-06 | El mockup asume generación de rótulos. | Resolver P-06. |
| I-12 | Mockup Transferencias vs. RF-AC-009/010 | Tipo "Física y digital" combinado; el F-02 solo define física o digital. | Confirmar si una transferencia puede ser mixta y ajustar el modelo. |
| I-13 | Mockup Bandeja vs. RN-AC-09 | No hay pestaña "Devuelta". | Agregar la pestaña en la maqueta. |
| I-14 | Mockup Plantillas vs. RF-AC-006 | 3 plantillas en lugar de 6 (faltan devolución, recordatorio, resumen). | Completar en la maqueta. |
| I-15 | Mockup móvil vs. D-02 | Texto "cárgalos a la nube"; los archivos se guardan localmente. | Cambiar el texto. |
| I-16 | Mockups vs. paleta institucional (D-10) | Naranja `#F6A007` y texto `#1E2332` en lugar de `#e8740e` y `#2c3e50`. | Usar la paleta oficial al implementar. |
| I-17 | F-02 §5.2 (n8n F1 a F11) vs. D-15 | El F-02 asigna a n8n también FUID, cargas digitales, historias, histórico e IA (F7–F11); el usuario decidió que n8n solo maneja comunicaciones. | Actualizar el F-02 en su próxima versión. |
| I-18 | F-02 HU-AC-14 vs. §2.3 (perfiles) | La historia dice que Secretaría General **importa** los Excel históricos; la matriz de perfiles le da solo **consulta**. | Implementado según la matriz (SGD-044): Secretaría consulta el histórico; importar exige `cargas.historico` (Archivo Central). Confirmar con el cliente; si Secretaría debe importar, basta agregar el permiso en `permiso_perfil`. |
| I-19 | RN-AC-10 sin formato definido | "El consecutivo histórico se adapta al formato del sistema" no dice qué número toma. | Implementado (migración 19): `TIPO-AAAA-9NNNNN`, bloque desde 900001 por tipo y año, para no chocar con el contador de las comunicaciones nuevas; el número del Excel queda en `consecutivo_original`. Un número repetido en el mismo año y archivo no se importa: se reporta para revisión. Confirmar con el cliente al recibir los Excel reales. |
