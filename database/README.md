# Base de datos — SGD · Módulo Archivo Central

PostgreSQL 18 propio (D-29, D-31), **sin Supabase**. Toda la lógica de negocio vive aquí: tablas, triggers, funciones `fn_*` (backend) y `n8n_*` (flujos de la Bandeja), RLS y auditoría inmutable. El backend se conecta directo con el driver `pg` (`backned_sistema_gestion_documental/lib/db.ts`) usando el rol `sgd_backend`.

```text
migrations/                 # se aplican en orden por nombre (fecha); nunca se editan una vez aplicadas
  20261007000100_base.sql   … 20261102000000_rls_nivel_formacion.sql (36 en total)
seed.sql                    # configuración obligatoria (parámetros, plantillas, permisos, tipos documentales); idempotente
seed_demo.sql               # SOLO desarrollo: dependencias, TRD, asuntos y programas ficticios de los mockups
datos/dependencias.sql      # dependencias reales para cargar a mano si se desea
tests/pruebas_reglas.sql    # pruebas de reglas de negocio (se revierten al final)
instalacion/                # SQL único generado por scripts/armar_instalacion.sh (no editar)
scripts/
  instalar_local.sh         # instala o actualiza una base: migraciones pendientes + seed.sql + rol sgd_backend + permisos
  probar_local.sh           # PostgreSQL temporal: instala, prueba reglas, concurrencia y permisos; lo borra al final
  armar_instalacion.sh      # une migraciones + seed en instalacion/01_….sql (para psql sin bash)
n8n/                        # contrato de las APIs que usa n8n (APIs_backend_n8n.md) y notas de tablas (TABLAS_N8N.md)
```

## Instalar o actualizar una base

```bash
DATABASE_URL=postgres://postgres:<clave>@<host>:5432/sgd SGD_BACKEND_PASSWORD=<clave del backend>   ./database/scripts/instalar_local.sh
```

- `DATABASE_URL` es un **superusuario** (crea extensiones `pg_trgm` y `unaccent` y el rol del backend).
- Lleva la cuenta en la tabla `sgd_migracion`: se corre en cada actualización y solo aplica lo nuevo. `select * from sgd_migracion order by nombre;` muestra lo aplicado.
- Crea o actualiza `sgd_backend`: `login`, `bypassrls`, `select/insert/update` en las tablas, uso de secuencias y `execute` en las funciones. **Sin `delete`** (no hay borrado físico, además del trigger que lo bloquea), no es dueño del esquema ni superusuario. Revoca `connect` a `public`.
- En Docker lo hace el servicio `migraciones` de `despliegue/docker-compose.yml` en cada `docker compose up`.
- Base restaurada desde un respaldo que ya tiene todo: `MARCAR_APLICADAS=1` solo registra las migraciones.
- **Nunca** cargar `seed_demo.sql` en producción.

> RLS está activo en todas las tablas y sin políticas: solo el dueño y `sgd_backend` (que salta RLS) leen y escriben. **Toda migración nueva** que cree una tabla debe hacer `alter table … enable row level security` (la prueba "RLS activo en todas las tablas" lo exige).

## Probar

```bash
PG_BIN="/c/Program Files/PostgreSQL/18/bin" bash database/scripts/probar_local.sh   # con PostgreSQL instalado
bash database/scripts/probar_local.sh --docker                                      # sin PostgreSQL: en postgres:18-alpine
```

Última ejecución (2026-11-04, `--docker`, PostgreSQL 18): 36 migraciones aplicadas con `instalar_local.sh`, segunda instalación sin cambios, seeds idempotentes, **164 verificaciones OK**, 40 consecutivos concurrentes sin repetir ni saltar y permisos de `sgd_backend` correctos (lee y ejecuta; no borra).

## Usuarios: sin login propio (D-13)

NOVA ya autentica a los usuarios con su backend (Django, sin acceso para nosotros). El módulo no tiene login:

1. El frontend (dentro de NOVA) ya tiene el token JWT del usuario.
2. Nuestro backend recibe ese token y llama a `GET {NOVA_API}/api/users/perfil/` **desde el servidor** con `Authorization: Bearer <token>`. Si NOVA responde 200, el usuario es auténtico; si no, 401.
3. Con la respuesta (`UsuarioAPI`: id, email, nombre, apellido, cédula, dependency, roles, is_staff, activo) ejecuta:
   ```sql
   select * from fn_sincronizar_usuario_nova('<json de NOVA>'::jsonb);
   ```
   Crea o actualiza la fila en `usuario` (clave `nova_user_id`) y mapea la dependencia de NOVA a la nuestra por UUID o por código.
4. Si `fn_usuario_puede_ingresar(id)` es falso (sin perfil asignado, inactivo o inactivo en NOVA), se responde 403.
5. El **perfil del módulo** (Archivo Central, Dependencia, Registro Académico, Secretaría General, Administrador) lo asigna un Administrador en `usuario.perfil`; los roles de NOVA solo se guardan como referencia.

⚠️ **Nunca** sincronizar con datos que mande el navegador sin validar el token contra NOVA: cualquiera podría hacerse pasar por otro usuario.

Primer administrador (una sola vez, tras su primer ingreso):
```sql
update usuario set perfil = 'administrador' where email = '<correo institucional>';
```

## Convenciones para el backend y n8n

- **Quién actúa**: las funciones `fn_*_usuario(p_usuario_id, …)` llaman a `fn_set_usuario_actual` dentro de su propia transacción; así la auditoría y los campos `*_por` registran a la persona. Una escritura directa (`db.from(…).insert/update`) se atribuye al sistema.
- **Autorización** antes de cada acción: `fn_tiene_permiso(usuario, 'funcion')` + `fn_puede_ver_dependencia(...)` / `fn_puede_ver_historia(...)`. Matriz en la tabla `permiso_perfil`.
- **Consultas, descargas e intentos denegados**: `fn_auditar('consultar'|'descargar'|'denegado', recurso, id, detalle, resultado)`. Los INSERT/UPDATE se auditan solos.
- **Archivos** (D-02): guardar en `<RAIZ_ARCHIVOS>/...` con nombre `<uuid>.<ext>`, insertar en `archivo` y referenciar con `archivo_id`. Servir siempre por id, nunca por ruta.
- **Consecutivos**: nunca calcularlos; los asigna el trigger al insertar en `comunicacion` (o `fn_siguiente_consecutivo`).
- **No hay DELETE**: un trigger lo bloquea en todas las tablas de negocio. Usar `estado = 'inactivo'` (catálogos) o anulación con `anulado_motivo`.

n8n solo maneja la **Bandeja de comunicaciones** (D-15); detalle en `n8n/TABLAS_N8N.md`.

| Flujo n8n | Función |
|---|---|
| F1 correo entrante | `fn_registrar_correo_entrante(message_id, nombre, correo, asunto, cuerpo, recibido_en, in_reply_to)` (idempotente) |
| F1 rama respuesta | `fn_buscar_comunicacion_respondida(asunto, in_reply_to)` → `update comunicacion set estado = 'respondida_dependencia'`; si es null → `correo_sin_asociar` |
| F2 remitir | `fn_remitir_comunicacion(id, dependencia_id, plazo_dias_habiles, message_id_enviado, mensaje)` |
| F3 responder | `fn_responder_remitente(entrada_id, asunto, cuerpo, message_id_enviado)` — solo tras envío exitoso |
| F4 recordatorios | `fn_comunicaciones_a_recordar()` (agrupar por dependencia) + `fn_registrar_recordatorio(id, message_id)` |

Cargas, FUID, historias, histórico e IA (`sugerencia_ia`, `v_asuntos`) los implementa el backend.

## Supuestos a validar

| Supuesto | Dónde | Pregunta |
|---|---|---|
| Expediente = dependencia + año + asunto (documentos) / la historia (historias) | `documento_sin_duplicados`, `historia_documento_sin_duplicados` | P-10 |
| Consecutivo `ENT-AAAA-NNNNNN` (el mockup usa `2026-CR-NNNNN`) | `fn_formatear_consecutivo` | P-17 |
| Un documento queda "clasificado" con asunto + fecha | `fn_trg_documento_preparar` | — |
| Transferencia física **o** digital (no mixta) | enum `tipo_transferencia` | P-18 |
| Solo Archivo Central descarga archivos | `seed.sql` → `permiso_perfil` | P-09 |
| `dia_festivo` vacío: cargar los festivos de Colombia | tabla `dia_festivo` | P-15 |
