# Backend — SGD · Módulo Archivo Central

Por ahora contiene la **base de datos** (PostgreSQL / Supabase). La tecnología del servidor de aplicación sigue por decidir (`ia_contexto/spec/decisiones.md` P-11).

```text
supabase/
  migrations/                     # aplicar en orden
    20261007000100_base.sql                     extensiones, enums, utilidades, bloqueo de borrado
    20261007000200_catalogos_y_usuarios.sql     dependencias, TRD, asuntos, catálogos, usuarios (NOVA), parámetros, plantillas, festivos
    20261007000300_archivos_cargas_documentos.sql archivo (id), lotes, transferencias, inventario FUID, documentos, sugerencias IA
    20261007000400_comunicaciones.sql           consecutivos atómicos, comunicaciones, estados, eventos, correos sin asociar, funciones F1–F4
    20261007000500_historias_academicas.sql     estudiantes, historias, documentos de historia
    20261007000600_auditoria_seguridad_vistas.sql auditoría inmutable, permisos, RLS, vistas
  seed.sql                        # configuración obligatoria (parámetros, plantillas, permisos, tipos documentales)
  seed_demo.sql                   # SOLO desarrollo: dependencias/TRD/asuntos/programas de los mockups
  tests/pruebas_reglas.sql        # pruebas de reglas de negocio (se revierten al final)
scripts/probar_local.sh           # levanta un PostgreSQL temporal y corre todo
n8n/TABLAS_N8N.md                 # flujos n8n de la Bandeja de comunicaciones (F1–F6): tablas, consultas y subida de adjuntos
```

## Probar localmente

Requiere PostgreSQL 15+ instalado (no usa ni modifica los servicios existentes):

```bash
PG_BIN="/c/Program Files/PostgreSQL/18/bin" bash scripts/probar_local.sh
```

Última ejecución (2026-10-07): 6 migraciones aplicadas, seeds idempotentes, **79 verificaciones OK** (49 de comportamiento esperado y 30 de rechazo de operaciones inválidas) y 40 consecutivos concurrentes sin repetir ni saltar.

## Aplicar en Supabase

Con Supabase CLI: `supabase db push` (usa `supabase/migrations/`) y luego ejecutar `seed.sql`. Sin CLI: pegar cada migración en orden en el SQL Editor, luego `seed.sql`. **No** ejecutar `seed_demo.sql` en producción.

> Supabase da permisos por defecto a `anon`/`authenticated` en tablas nuevas. La migración 06 los revoca y activa RLS; **toda migración futura debe repetir** `enable row level security` y los `revoke` para sus tablas.

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

- Al iniciar cada transacción: `select set_config('app.usuario_id', '<usuario.id>', true);` — así la auditoría y los campos `*_por` registran quién hizo la acción. Sin esto se atribuye al sistema.
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
