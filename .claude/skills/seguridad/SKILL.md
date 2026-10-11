---
name: seguridad
description: Validación de inputs, manejo de secretos, dependencias, autenticación y headers de seguridad de Sistema de Gestión Documental (SGD). Úsala al tocar formularios, APIs, variables de entorno, autenticación o configuración de despliegue.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Seguridad — Sistema de Gestión Documental (SGD)

## Secretos y variables de entorno

- Los archivos `.env` nunca se suben al repo (verificar `.gitignore`).
- Toda variable nueva se documenta en `.env.example` con un valor vacío o de ejemplo.
- **Regla crítica:** las variables públicas del cliente (`VITE_*`, `NEXT_PUBLIC_*`, `EXPO_PUBLIC_*`, o las que van dentro de la app móvil) las puede leer cualquiera. Las claves de APIs de pago o privilegiadas van en un backend/función serverless.
- Frontend (`NOVA_FT/.env.example`): `VITE_API_URL`, `VITE_RECAPTCHA_SITE_KEY` (pública), `VITE_GOOGLE_CLIENT_ID` (público). Ninguna clave de Supabase con rol `service_role` puede ir en `VITE_*`.
- La credencial `service_role` de Supabase, las del buzón institucional y la del servicio de IA viven **solo** en el backend y en n8n (credenciales de n8n), nunca en el repo.

## Validación de inputs

- Validar en el cliente (UX, H5) **y** en el servidor (seguridad).
- No usar `eval()`/`new Function()` con datos del usuario.
- Sanitizar todo contenido que se renderice como HTML; no usar `dangerouslySetInnerHTML`/`v-html` con datos sin sanitizar.

## Autenticación y autorización

Proveedor: por definir (`ia_contexto/spec/decisiones.md` P-16).

Reglas del módulo Archivo Central (RF-AC-023, RNF-AC-02):
- 5 perfiles fijos: Archivo Central, Dependencia, Registro Académico, Secretaría General, Administrador. Matriz en `ia_contexto/spec/product.md#usuarios--roles`.
- El permiso se valida en el **backend / RLS** sobre la función **y el recurso** (p. ej. una Dependencia solo accede a registros de su `dependencia_id`; Registro Académico solo a historias activas). Ocultar en la UI no es control de acceso.
- Todo intento denegado se registra en la auditoría.
- Usuario inactivo no inicia sesión.

## Datos personales y archivo (Ley 1581 de 2012, Ley 594 de 2000)

- Historias académicas, remitentes y comunicaciones contienen **datos personales**: nunca en logs, URLs, mensajes de error ni datos de prueba reales (usar datos ficticios).
- Archivos **no públicos**: servir solo por endpoint con sesión o enlace temporal firmado; el cliente pide el archivo por su **id**, nunca por ruta; nunca exponer la ruta de las carpetas locales.
- Cada consulta a historias académicas y cada descarga queda **auditada**.
- **Sin borrado físico** (RN-AC-12): no crear endpoints DELETE para entidades de negocio; usar anulación con motivo.
- Auditoría **append-only**: sin UPDATE/DELETE para nadie.
- Integridad: SHA-256 por archivo, restricción única (expediente, hash).
- Enviar contenido a un servicio de IA externo implica transferir datos personales a un tercero: solo con el servicio aprobado (P-13) y **nunca** con historias académicas (RN-AC-13).
- Correo entrante es **entrada no confiable**: validar tipo y tamaño de adjuntos (PDF/JPG/PNG/XLSX, máx. parametrizado), no ejecutar ni renderizar HTML de correos sin sanitizar.
- Excel importados (FUID, histórico, catálogos): validar columnas y tipos; neutralizar fórmulas al exportar (CSV/Excel injection).

## Headers / CSP (web)

<!-- COMPLETAR: CSP y headers configurados (index.html, vercel.json, netlify.toml, next.config). Si no existen, crear tarea. -->

- No relajar la CSP ni los headers "para que funcione" sin documentar el riesgo.

## Móvil (si aplica)

- Permisos mínimos y solicitados en contexto.
- HTTPS obligatorio; nada de tráfico en texto plano.
- No registrar (log) datos sensibles.

## Dependencias

- Antes de agregar una dependencia, revisar si ya existe una que resuelva el problema, y su mantenimiento y reputación.
- Ejecutar `npm audit` (o el equivalente del stack) periódicamente.

## Acciones prohibidas

- Exponer claves de API en el bundle del cliente.
- Desactivar protecciones (StrictMode, CSP, validaciones) sin justificar y registrar el motivo.
