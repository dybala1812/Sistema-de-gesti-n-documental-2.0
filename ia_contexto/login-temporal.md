# Login temporal de pruebas por perfil — ⚠️ BORRAR ANTES DEL DESPLIEGUE

Creado el 2026-10-28 para probar los permisos de cada perfil del SGD sin pasar por el login de NOVA.
En producción el módulo usa **solo** el token de NOVA (regla 10 de CLAUDE.md). Tarea de retiro: **SGD-091**.

## Cómo se usa

1. Backend `backned_sistema_gestion_documental/.env.local`: `SGD_LOGIN_TEMPORAL=true` y `SGD_LOGIN_TEMPORAL_CLAVE=<clave de al menos 12 caracteres>` (ya configurados en la máquina de desarrollo).
2. Frontend `NOVA_FT/.env.local`: `VITE_LOGIN_TEMPORAL=true`.
3. Con `npm run dev` en los dos, abrir **http://localhost:5173/login-temporal** (o el botón pequeño **Login 2** junto a "Ingresar").
4. Elegir el perfil (y la dependencia si es Dependencia), escribir la clave y entrar. "Salir" cierra la sesión temporal.

Usuarios ficticios (se crean o actualizan al entrar, con `fn_sincronizar_usuario_nova`):

| Perfil | Correo |
|---|---|
| Archivo Central | `archivo.central@prueba.sgd.test` |
| Administrador | `administrador@prueba.sgd.test` |
| Dependencia | `dependencia@prueba.sgd.test` (la dependencia se elige al entrar) |
| Registro Académico | `registro.academico@prueba.sgd.test` |
| Secretaría General | `secretaria.general@prueba.sgd.test` |

## Por qué no expone nada

- La clave vive solo en el `.env.local` del backend; el frontend no tiene ningún secreto (ninguna variable `VITE_*` con tokens).
- El backend entrega un token de sesión firmado (HMAC-SHA256) que vence en 8 horas, con una llave aleatoria en memoria: reiniciar el backend cierra todas las sesiones.
- Solo sirve para los usuarios `@prueba.sgd.test`; nunca para un usuario real de NOVA.
- No funciona en producción: el backend responde 404 si `NODE_ENV=production`, y en el build del frontend la ruta, la página y el botón no existen (comprobado buscando en `NOVA_FT/dist`).
- Cinco claves incorrectas bloquean ese origen 10 minutos; los intentos (correctos y fallidos) quedan en la auditoría (`recurso_tipo = login_temporal`).
- La sesión se guarda en `sessionStorage` (solo esa pestaña).

## Qué borrar al desplegar (todo está marcado con ⚠️ TEMPORAL)

Backend:
- `lib/loginTemporal.ts` y `app/api/login-temporal/route.ts`.
- `lib/auth.ts`: el import de `./loginTemporal` y el bloque `if (token.startsWith(PREFIJO_TOKEN_TEMPORAL))` de `obtenerUsuarioAutenticado`.
- `.env.local` y `.env.example`: `SGD_LOGIN_TEMPORAL` y `SGD_LOGIN_TEMPORAL_CLAVE`.

Frontend (`NOVA_FT/`):
- `src/app/lib/loginTemporal.ts` y `src/app/pages/login-temporal/`.
- `src/app/lib/config.ts`: `LOGIN_TEMPORAL`.
- `src/app/routes.tsx`: la constante `LoginTemporal`, la ruta `login-temporal` y el destino `/login-temporal` de `ArchivoCentralRoute`.
- `src/app/context/AuthContext.tsx`: `usuarioDeSesionTemporal`, `NOMBRE_PERFIL`, el estado `sesionTemporal` y `borrarSesionTemporal()` en `logout`.
- `src/app/lib/sgdApi.ts` y `src/app/services/archivoCentralApi.ts`: el uso de `leerSesionTemporal` / `borrarSesionTemporal` (queda solo `tokens.getAccess()` de NOVA).
- `src/app/components/layout/InstitutionalNavbar.tsx` (archivo de NOVA): el botón "Login 2" y las condiciones `!LOGIN_TEMPORAL` que ocultan "Registrarse" (vuelve a verse como en NOVA).
- `.env.local` y `.env.example`: `VITE_LOGIN_TEMPORAL`.

Base de datos (opcional): inactivar los usuarios `@prueba.sgd.test` con motivo (no se borran: RN-AC-12).

Comprobación final: `grep -rn "TEMPORAL" backned_sistema_gestion_documental/lib backned_sistema_gestion_documental/app NOVA_FT/src` no debe devolver nada del login, y el build de producción no debe contener `login-temporal` ni `sgdtmp`.

## Cambios de seguridad hechos al mismo tiempo (se quedan)

- El frontend ya no llama a n8n: remitir y enviar la respuesta pasan por el backend (`POST /api/comunicaciones/{id}/enviar-remision` y `/enviar-respuesta`), que revisa el permiso y manda a n8n el id del usuario autenticado. Antes el token de n8n (`VITE_N8N_WEBHOOK_TOKEN`, igual a `N8N_SERVICE_TOKEN`) y un `usuario_id` fijo iban dentro del JavaScript.
- Se quitó `VITE_SGD_DEV_TOKEN` del frontend: el build de producción lo llevaba incrustado (`archivoCentralApi.ts` no revisaba que fuera desarrollo). `SGD_DEV_TOKEN` queda solo en el backend, para pruebas por script, y se rotó.
- Nueva variable del backend: `N8N_WEBHOOK_REMITIR_URL` (webhook de F2).
