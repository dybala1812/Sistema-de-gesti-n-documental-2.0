---
name: seguridad
description: Validación de inputs, manejo de secretos, dependencias, autenticación y headers de seguridad de {{PROYECTO}}. Úsala al tocar formularios, APIs, variables de entorno, autenticación o configuración de despliegue.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Seguridad — {{PROYECTO}}

## Secretos y variables de entorno

- Los archivos `.env` nunca se suben al repo (verificar `.gitignore`).
- Toda variable nueva se documenta en `.env.example` con un valor vacío o de ejemplo.
- **Regla crítica:** las variables públicas del cliente (`VITE_*`, `NEXT_PUBLIC_*`, `EXPO_PUBLIC_*`, o las que van dentro de la app móvil) las puede leer cualquiera. Las claves de APIs de pago o privilegiadas van en un backend/función serverless.
<!-- COMPLETAR: variables reales y dónde se usan. -->

## Validación de inputs

- Validar en el cliente (UX, H5) **y** en el servidor (seguridad).
- No usar `eval()`/`new Function()` con datos del usuario.
- Sanitizar todo contenido que se renderice como HTML; no usar `dangerouslySetInnerHTML`/`v-html` con datos sin sanitizar.

## Autenticación y autorización

<!-- COMPLETAR: proveedor (propio, Supabase, Firebase, Auth0…), dónde se guardan los tokens (en móvil: almacenamiento seguro / Keychain / Keystore, nunca AsyncStorage en texto plano) y cómo se verifican los roles. Borrar si no hay autenticación. -->

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
