---
name: seguridad
description: Validación de inputs, manejo de secretos, dependencias y headers de seguridad de EDUCALC XE.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Seguridad — EDUCALC XE

## Secretos y variables de entorno

- El archivo `.env` y `.env.example` viven en `vite-project/`.
- **Regla crítica**: todo lo que empiece por `VITE_` se incrusta en el JavaScript que descarga el navegador. No uses `VITE_OPENAI_API_KEY` u otros secrets sensibles en el cliente para producción real.
- No subir archivos `.env` al repositorio (ya están en `.gitignore`).
- Si se agrega una variable sensible nueva, documentarla en `.env.example` con valor vacío o de ejemplo.

## Content Security Policy

El `index.html` define un CSP restrictivo:

```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' https://img.youtube.com https://i.ytimg.com data: blob:; frame-src https://www.youtube.com https://www.youtube-nocookie.com; connect-src 'self' https://api.openai.com;" />
```

- No relajar el CSP sin evaluar el riesgo.
- Si se agrega un nuevo origen de scripts, estilos, imágenes o frames, actualizar el CSP.

## Headers de seguridad en Vercel

`vercel.json` configura headers de seguridad:

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Referrer-Policy: strict-origin-when-cross-origin`

Mantener estos headers al editar `vercel.json`.

## Validación de inputs

- No usar `eval()` ni `new Function()` para procesar expresiones matemáticas del usuario.
- Usar `mathjs` o parsers controlados para evaluar expresiones.
- Sanitizar cualquier contenido que se renderice como HTML (KaTeX ya escapa por defecto; no desactivar escapes sin justificación).

## Dependencias

- Antes de agregar una dependencia, evaluar si ya existe una en el proyecto que resuelva el problema.
- Revisar la reputación y mantenimiento de nuevas librerías.
- Ejecutar `npm audit` periódicamente.

## Acciones prohibidas

- No exponer claves de API en el bundle del cliente.
- No deshabilitar `StrictMode` de React sin justificación.
- No modificar headers de seguridad para "que funcione" sin documentar el riesgo.

## Tarea de deuda técnica

- [ ] LH-004: Auditar manejo de `VITE_OPENAI_API_KEY` y otras variables de entorno; evaluar migrar la llamada a OpenAI a una función serverless.
