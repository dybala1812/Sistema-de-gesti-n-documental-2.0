# Contexto del Proyecto

## Producto

**Sistema de Gestión Documental (SGD) — Módulo Archivo Central** de la Universidad Autónoma (Uniautónoma del Cauca). Proyecto de práctica profesional.

Reemplaza los Excel por año, los PDF mensuales por oficina y el reenvío manual de correos con un único sistema donde se **registra, custodia y consulta** lo que llega al Archivo Central: documentos, transferencias documentales, comunicaciones por correo e historias académicas.

- Documento fuente: `ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx` (v1.1, 2026-10-07). Pendiente de firma del cliente.
- Versión operativa: `ia_contexto/spec/` (product, requirements, business-rules, architecture, decisiones, trazabilidad).
- Fase: especificación aprobada internamente, **antes de construir** (falta firma y validación de maquetas).

## Usuarios

Perfiles fijos: **Archivo Central** (usuario principal), **Dependencia**, **Registro Académico**, **Secretaría General**, **Administrador**.

Tono de comunicación: español, institucional, claro y directo; usar el vocabulario del cliente (asunto = serie documental, TRD, FUID, transferencia, foliar, rotular).

## Plataforma

Web responsive (React) + PWA móvil para escaneo con la cámara.

## Stack actual

- Frontend existente: `NOVA_FT/` (portal NOVA) — React + TypeScript + Vite 6 + Tailwind v4 + Radix/shadcn + React Router 7 + react-pdf + exceljs.
- Base de datos: PostgreSQL en **Supabase**.
- Archivos: guardados localmente en carpetas; en BD un id por archivo que lo referencia (tabla `archivo`).
- Automatización: **n8n** (flujos F1–F11) con escritura directa en Supabase.
- Backend de la aplicación: **por definir** (P-11). Carpeta reservada: `backned_sistema_gestion_documental/` (vacía).

## Ubicación

Frontend en `NOVA_FT/` (repositorio Git anidado). Skills en `.claude/skills/` y espejo en `.agents/skills/`. Tablero y spec en `ia_contexto/`.

## Módulos / pantallas

| Módulo | Propósito | RF |
|---|---|---|
| Inicio | Pendientes, comunicaciones nuevas/vencidas, transferencias en proceso | — |
| Catálogos | Dependencias, TRD, asuntos, tipos, programas, ubicaciones, usuarios, parámetros, plantillas | 001–006 |
| Centro de cargas | Lotes con avance e informe | 007, 008 |
| Transferencias | Físicas (FUID + acta) y digitales (FUID + archivos) | 009, 010 |
| Clasificación / Archivo / Buscar | Por clasificar, árbol Dependencia→Año→Asunto, visor, búsqueda, IA opcional | 011–014 |
| Comunicaciones | Bandeja por estados, remitir, responder, recordatorios, sin asociar, histórico | 015–019 |
| Historias académicas | Árbol Estado→Año→Nivel→Programa, ficha, carga masiva | 020, 021 |
| App móvil | Escaneo y subida | 022 |
| Auditoría / Control | Permisos, auditoría, anulación | 023, 024 |

## Dominio — reglas que nunca se rompen

1. Archivo = **Dependencia → Año → Asunto**; un documento pertenece a un solo asunto; asuntos por dependencia ligados a TRD.
2. Transferencia anual hasta **año actual − 2**. Física = solo inventario; digital = todos los archivos.
3. Consecutivos **ENT/SAL/INT-AAAA-NNNNNN** por función atómica de BD, reinicio anual.
4. Comunicación: Nueva → Remitida → Respondida por dependencia (↺ Devuelta) → Cerrada (solo al responder al remitente); Anulada.
5. Duplicado = mismo hash en el mismo expediente.
6. **Sin borrado físico**; anulación con motivo; auditoría inmutable.
7. **IA solo sugiere**, nunca en historias académicas.
8. Historias activas → Registro Académico; retirados/graduados → Archivo Central.
9. Datos personales protegidos (Ley 1581); archivos nunca públicos.

Detalle: `ia_contexto/spec/business-rules.md`.

## Identidad visual

- Marca: Universidad Autónoma — Archivo Central
- Estilo: institucional sobrio: confiable, ordenado, legible, cálido
- Paleta institucional (obligatoria): `navy` `#1e3a5f` (primario), `orange` `#e8740e` (acción), `gold` `#c89b14` (acento), `beige` `#f3ede1` / `beigeAlt` `#ede6d8` (fondos), `text` `#2c3e50`, `muted` `#6b7a8d`, `card` `#ffffff`, `border` `rgba(30,58,95,0.09)`
- Detalle, reglas y contraste: `../frontend/color-palette.md`
- Fuentes: por definir (`NOVA_FT/src/styles/fonts.css` vacío)
- Guía detallada: `../frontend/`

## Activos

Logos e imágenes en `NOVA_FT/public/` y `NOVA_FT/src/assets/`. Maquetas: `ia_contexto/diseno/` (pendiente de validar, SGD-002).
