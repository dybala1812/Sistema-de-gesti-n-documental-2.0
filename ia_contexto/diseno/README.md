# Diseño

Maquetas, prototipos exportados, capturas y guía de interfaz de referencia. La guía que deben seguir los agentes al implementar está en `.agents/skills/frontend/`; aquí va el material de origen.

| Archivo / carpeta | Qué es |
|---|---|
| `.claude/skills/frontend/color-palette.md` | Paleta institucional oficial (tokens, reglas y contraste) — referencia obligatoria |
| `mockups_archivo_central_y_movil.html` | **Mockups interactivos** del módulo Archivo Central: 14 pantallas de escritorio + 3 pantallas de la app móvil. Abrir en el navegador (requiere JavaScript); conmutador **Escritorio / Móvil** abajo a la derecha. Recibido 2026-10-07. **Estado: pendiente de validar con la jefatura (SGD-002).** |

> Los mockups son **referencia visual y de flujo**. Si contradicen el F-02 o `spec/`, manda el F-02 hasta que se decida (ver "Diferencias con el F-02" abajo y `spec/decisiones.md`). Los nombres, cédulas y correos de los mockups son datos de ejemplo.

---

## Mockups — Escritorio

### Estructura general (layout)

- **Barra superior** navy: logo "UAC", "Gestión Documental · Universidad Autónoma del Cauca · Archivo Central", buscador global "Buscar en todo el archivo" (atajo `/`), ayuda, campana de notificaciones con contador, usuario (nombre + perfil) y cerrar sesión.
- **Menú lateral** agrupado por secciones, con contadores en badge:
  - **General**: Inicio
  - **Ingreso**: Centro de cargas, Transferencias (11)
  - **Bandejas**: Por clasificar (8, badge naranja), Clasificados
  - **Consulta**: Archivo, Buscar, Historias académicas
  - **Comunicaciones**: Bandeja, Correos sin asociar, Registro histórico
  - **Administración**: Catálogos, Plantillas de correo, Auditoría
- **Contenido**: migas de pan ("Está aquí: Archivo Central › Sección › Pantalla"), eyebrow en mayúsculas dorado (p. ej. "PANEL GENERAL", "INGRESO · BANDEJA 1"), título grande serif, descripción de una línea y acción principal arriba a la derecha (normalmente **Cargar lote**).
- Fondo beige, tarjetas y tablas blancas, estados en chips de color.

### Pantallas

| # | Pantalla | Qué muestra | RF |
|---|---|---|---|
| 1 | **Inicio** | 4 KPI (documentos por clasificar, transferencias en proceso, historias cargadas, alertas); **Notificaciones** con tipo (POR CLASIFICAR, LE TOCA TRANSFERIR), texto, fecha/plazo y "Marcar todas como leídas"; tarjeta **Faltan por transferir este año** ("4 de 8 dependencias deben entregar 2024 (año actual − 2)") con lista y estado Pendiente. | — |
| 2 | **Centro de cargas** | 6 tarjetas: **A** Documento individual · **B** Transferencia física (solo acta/FUID) · **C** Transferencia digital (FUID + archivos por asunto) · **D** Historias académicas masivas (por lotes, con pausa) · **E** Registro histórico (Excel, repetible sin duplicar) · **F** App móvil. Cada una indica quién la usa. **Proceso común** en 6 pasos: Recepción → Validación (formato, tamaño, daño) → Huella y duplicados (SHA-256) → Registro → Auditoría → Resultado (informe descargable). Tabla **Últimos lotes**: Lote (`L-2026-041`), Carga, Destino, Usuario, Fecha, Estado (Completado / Con errores / Cancelado), Avance %, Resultado ("117 acept. · 2 dup. · 1 err."). | 007, 008 |
| 3 | **Transferencias** | Tarjetas: año transferible en 2026 (hasta 2024), próxima transferencia (2027 → 2025), faltan por entregar (4 de 8). Tabla: Código (`TR-2026-001`), Dependencia, Año, Tipo (Física / Digital / **Física y digital**), Estado (Recibida / En proceso, con sub-estado "5 por clasificar", "Cajas por recibir"), Fecha, Quién entrega, Contenido (Documentos / Historias académicas + descripción), Unidades. Botón **Nueva transferencia**. | 009, 010 |
| 4 | **Por clasificar** (Bandeja 1) | Filtros por dependencia y origen (Transferencia / Lote de carga). Tabla: Nombre del archivo + páginas, Dependencia, Año, Origen (`Transferencia TR-2025-002`), Fecha de carga, Estado, acción **Clasificar**. Botón **Empezar a clasificar**. | 011 |
| 5 | **Clasificados** (Bandeja 2) | Filtro por dependencia. Tabla: Consecutivo + fecha (`194/2024`), Tipo (Entrada/Salida/Interno), Datos (título + remitente/destinatario), **Ruta · TRD** (`Rectoría / 2024 / Informes de gestión` · `TRD 100.03`), Caja · carpeta, Estado, **Abrir PDF**. | 011, 013 |
| 6 | **Archivo** | Árbol **Dependencia → Año → Asunto** con contador por dependencia; listado paginado (Consecutivo, Tipo, Documento + asunto · TRD, Estado). | 013 |
| 7 | **Buscar** | Filtros: Año, Mes, Dependencia, Tipo, Asunto, Consecutivo, Persona, Código TRD. Resultados "169 resultados · Página 1 de 17" (Consecutivo, Tipo, Documento, Dependencia · asunto, TRD, Estado). | 014 |
| 8 | **Historias académicas** | Árbol **Estado → Año → Nivel → Programa** (Retirados 30, Graduados 21); botón **Carga masiva por carpeta**; aviso "el orden de niveles está por confirmar". Tabla alfabética: Apellidos y nombres, Cédula, Código (`UAC-2015-1504`), Programa + nivel, Historia (Graduado/Retirado). | 020, 021 |
| 9 | **Bandeja de comunicaciones** | Correos de `correspondencia@uniautonoma.edu.co` registrados por n8n. **Alerta**: "6 comunicaciones llevan 5 días o más remitidas sin respuesta" + "Ver solo estas". Pestañas con contador: Nuevas, Remitidas, Respondidas, Cerradas, Anuladas, Todas. Filtros: persona/consecutivo, año, mes, dependencia, tipo, estado. Tabla: Consecutivo (`2026-CR-01377` + tipo), Fecha, Remitente (nombre + correo), Asunto, Dependencia ("Sin asignar"), Estado, Días, nº de adjuntos. | 015–018 |
| 10 | **Correos sin asociar** | Explica que n8n asocia por la etiqueta del consecutivo en el asunto (`[2026-CR-01377]`). Tabla: Recibido, De, Asunto + adjuntos, **Motivo** (Sin etiqueta en el asunto / La etiqueta no coincide / Remitente externo sin etiqueta), acciones **Asociar a comunicación** / **Crear como nueva**. Panel de detalle del correo con **"Posible coincidencia"** sugerida. | 018 |
| 11 | **Registro histórico** | Selector de año (2019–2026) y filtro Todas/Recibidas/Enviadas/Internas; botón **Importar Excel**. Calendario de 12 meses con total y desglose "cerradas en el sistema · importadas de Excel"; meses futuros "Aún no llega". | 019 |
| 12 | **Catálogos** | Pestañas con contador: Dependencias, Años de transferencia física, TRD, Asuntos por dependencia, Tipos documentales, Programas académicos, Usuarios, Ubicaciones físicas (opcional). Filtro por estado. Tabla de dependencias: Código (100, 110…), Nombre, Dependencia superior, Responsable, Correo, Estado, acciones Editar / Inactivar. | 001–005 |
| 13 | **Plantillas de correo** | Lista: Acuse de recibo, Remisión a dependencia, Respuesta al estudiante. Editor de asunto y cuerpo, **variables** `{consecutivo} {nombre} {asunto} {dependencia} {fecha} {respuesta}`, Guardar / Descartar / Restablecer texto original, **vista previa** con una comunicación real. | 006 |
| 14 | **Auditoría** | Filtros: Usuario, Acción, Fecha, Documento. Tabla: Fecha y hora, Usuario + perfil, Acción (Inició sesión, Clasificó documento, Consultó documento, Anuló documento, Importó TRD, Registró transferencia, Carga masiva de historias, Imprimió rótulos…), Documento afectado. | 023 |

Datos de ejemplo útiles: dependencias con códigos 100 Rectoría, 110 Secretaría General, 120 Mercadeo, 130 Dirección Administrativa, 140 Gestión Documental, 150 Registro Académico, 160 Talento Humano, 170 Financiera, 180 Bienestar Universitario; TRD con formato `100.03` (código dependencia + serie).

## Mockups — App móvil (PWA)

Flujo en 3 teléfonos interactivos con indicador de pasos (Ingresar → Capturar → Datos y carga):

1. **Inicio de sesión**: logo UAC, "Archivo Central — Escanea documentos y cárgalos desde tu celular", correo institucional + contraseña, "Recordar mi correo en este celular", Ingresar, ayuda. "Acceso solo para personal de Archivo Central y dependencias."
2. **Escáner**: cámara con marco guía ("Encuadra el documento dentro del marco"), **recorte automático**, botón Galería, Listo; usuario visible (Diana Paz · Archivo Central).
3. **Carga con formulario**: miniaturas de páginas (1, 2, 3), Título*, Dependencia, Año*, Tipo (Entrada/Salida/Interno), **Destino (Archivar ya / Por clasificar)**, Asunto*, Consecutivo*, Fecha*, Remitente, Caja, Carpeta; vista **"Quedará en: Rectoría / 2026 / Comunicaciones"**; botón **Subir**.

## Diferencias con el F-02 (registradas en `spec/decisiones.md` I-08 a I-16)

| Tema | Mockup | F-02 / spec |
|---|---|---|
| Formato de consecutivo de comunicaciones | `2026-CR-01377`, etiqueta `[2026-CR-01377]` | `ENT/SAL/INT-AAAA-NNNNNN`, etiqueta `[SGD consecutivo]` |
| Historias laborales / Talento Humano | Auditoría muestra "Consultó historia laboral" | Excluidas en v1.1 |
| Borrado | Catálogos: "…activar o inactivar y **eliminar**" | Sin borrado; solo inactivar |
| Rótulos | Auditoría: "Imprimió rótulos" | Pendiente (P-06) |
| Tipo de transferencia | "Física y digital" combinada | Física **o** digital |
| Estado "Devuelta" | Sin pestaña Devuelta en la bandeja | Estado activo de RN-AC-09 |
| Plantillas | 3 (acuse, remisión, respuesta) | 6 (+ devolución, recordatorio, resumen) |
| App móvil | "cárgalos a la nube" | Archivos locales en carpetas (D-02) |
| Colores | Naranja `#F6A007`, texto `#1E2332` | Paleta: `orange #e8740e`, `text #2c3e50` (navy, beige y muted coinciden) |

Datos que el mockup aporta y el F-02 no tenía: buzón `correspondencia@uniautonoma.edu.co`; alerta de remitidas sin respuesta a los **5 días**; catálogo "Años de transferencia física"; código de estudiante `UAC-AAAA-NNNN`; destino "Archivar ya / Por clasificar" en la app; login de la app con correo institucional + contraseña.
