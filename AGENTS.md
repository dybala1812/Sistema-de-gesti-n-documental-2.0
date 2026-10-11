# Sistema de Gestión Documental (SGD) — Módulo Archivo Central

Universidad Autónoma (Uniautónoma del Cauca) · práctica profesional. Reemplaza Excel/PDF manuales por un sistema que **registra, custodia y consulta** documentos, transferencias, comunicaciones por correo e historias académicas.

## Dónde está todo

- **Requisitos (fuente que manda):** `ia_contexto/fuentes/F-02_Archivo_Central_v1.1.docx` (texto: `.md` al lado).
- **Spec operativa:** `ia_contexto/spec/` → `product.md`, `requirements.md` (RF-AC-001…024 + RNF), `business-rules.md` (RN-AC-01…14), `architecture.md`, `decisiones.md` (decisiones, **preguntas abiertas**, inconsistencias), `trazabilidad.md`, `historias/`.
- **Mockups (cómo se ve la app):** `ia_contexto/diseno/mockups_archivo_central_y_movil.html` (abrir en navegador; escritorio + móvil). Descripción por pantalla y diferencias con el F-02: `ia_contexto/diseno/README.md`. Al construir una pantalla, seguir su mockup salvo donde contradiga el F-02.
- **Tablero:** `ia_contexto/tareas-*.md` + `historial.md` (skill `project-manager`). Prefijo de tareas `SGD-NNN`.
- **Cómo programar:** `.claude/skills/` (espejo `.agents/skills/`; mantener ambas sincronizadas): `desarrollo`, `seguridad`, `testing`, `git`, `frontend/`.
- Frontend: `NOVA_FT/` (React + TS + Vite + Tailwind v4 + shadcn; repo Git anidado). Backend: `backned_sistema_gestion_documental/` — **base de datos lista** en `supabase/` (migraciones, seeds, pruebas: `scripts/probar_local.sh`); servidor de aplicación por decidir (P-11). BD: Supabase PostgreSQL. Automatización: n8n (F1–F11).

## Antes de escribir código

1. El F-02 debe estar **firmado** (SGD-000) y las maquetas **validadas** (SGD-002).
2. Leer el RF, sus reglas RN-AC y `decisiones.md`. **Lo que está en "Preguntas abiertas" no se implementa por suposición.**
3. Seguir el ciclo de `project-manager`: tarea → rama → implementar → verificar → mover tarea + historial.

## Reglas de negocio que nunca se rompen

1. Archivo = **Dependencia → Año → Asunto**; un documento = un asunto; asuntos por dependencia, cada uno con código **TRD**.
2. Transferencias anuales hasta **año actual − 2**. Física = solo FUID + acta (sin escanear). Digital = FUID + todos los archivos.
3. Consecutivos **`ENT|SAL|INT-AAAA-NNNNNN`** solo por **función atómica de la BD**, por tipo, reinicio anual.
4. Comunicación: **Nueva → Remitida → Respondida por dependencia (↺ Devuelta) → Cerrada** (solo al enviar respuesta al remitente) · **Anulada**.
5. Duplicado = mismo **SHA-256** en el mismo expediente → no se registra.
6. **Sin borrado físico**: inactivar/anular con motivo. **Auditoría inmutable** de toda acción (incluidos intentos denegados).
7. Archivos **guardados localmente en carpetas**; en la BD cada archivo tiene un **id** (tabla `archivo`) que lo referencia, junto con su ruta relativa, hash y metadatos. Los registros (documento, adjunto…) apuntan al archivo por ese id. Nunca binarios en la BD.
8. **IA solo sugiere** (confirmación humana) y **nunca** en historias académicas.
9. Historias activas → Registro Académico; retirados/graduados → Archivo Central.
10. **Sin login propio**: el usuario viene autenticado de NOVA; el backend valida el token con `GET /api/users/perfil/` de NOVA y sincroniza `usuario` con `fn_sincronizar_usuario_nova`. Permisos por **perfil y dependencia** validados en backend/RLS. Perfiles fijos: Archivo Central, Dependencia, Registro Académico, Secretaría General, Administrador.
11. Datos personales (Ley 1581): nunca en logs/URLs; datos de prueba ficticios; archivos nunca públicos.
12. Procesos masivos y flujos n8n **idempotentes** (Message-ID, hash) y tolerantes a fallos por elemento.
13. **n8n solo maneja la Bandeja de comunicaciones** (F1 correo entrante, F2 remitir, F3 responder, F4 recordatorios, F5 envío, F6 errores) y **habla solo con el backend**: 19 APIs `POST /api/n8n/*` + `POST/GET /api/archivos` (D-19, contrato `database/n8n/APIs_backend_n8n.md`); cada API llama a su función SQL `n8n_*` (migración 09). Cargas, transferencias/FUID, historias, histórico e IA los hace el backend. Contrato: `backned_sistema_gestion_documental/n8n/TABLAS_N8N.md`.

Normativa: Ley 594/2000, Decreto 1080/2015, Ley 1581/2012, Decreto 1377/2013. Calidad: ISO/IEC 25010. Cobertura ≥ 60 % en consecutivos, estados y permisos.

## Frontend dentro de NOVA (D-16, D-17)

El módulo vive en el **Panel de Área de NOVA** (`NOVA_FT/src/app/pages/tickets/AreaDashboard.tsx`) como un módulo más de la barra lateral; cada módulo es un componente propio (ej. `pages/comunicaciones/ComunicacionesArea.tsx`, mismo patrón que `pages/inventario/InventarioArea.tsx`). Dentro de NOVA se usan **los colores de NOVA** (Tailwind gris/blanco, navy `#1e3a5f`, naranja de acento); los mockups solo dan la distribución. La paleta institucional de abajo aplica a piezas fuera de NOVA (documentos, plantillas, apps independientes).

## Paleta institucional

Usar SIEMPRE estos tokens antes de introducir cualquier color nuevo. Detalle, contraste y mapeo al tema: `.claude/skills/frontend/color-palette.md`.

| Token | Valor | Uso |
|---|---|---|
| `beige` | `#f3ede1` | Fondo principal |
| `beigeAlt` | `#ede6d8` | Fondo alterno / bandas |
| `navy` | `#1e3a5f` | Títulos, encabezados, botón primario |
| `orange` | `#e8740e` | CTA / highlight de prioridad |
| `gold` | `#c89b14` | Acento informativo, indicadores |
| `text` | `#2c3e50` | Texto principal |
| `muted` | `#6b7a8d` | Texto de apoyo, metadatos |
| `card` | `#ffffff` | Superficies, tablas, paneles |
| `border` | `rgba(30,58,95,0.09)` | Bordes tenues |

Reglas: sin colores hardcodeados si existe token; botón primario `navy`, secundario `orange`, acento `gold`; alternar fondos `beige`/`beigeAlt`; `gold` nunca como texto sobre fondo claro; texto sobre `orange` solo grande y bold; validar contraste en desktop y móvil.
