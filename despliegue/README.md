# Despliegue — SGD · Módulo Archivo Central

La guía completa está en [README_DEPLOY.md](../README_DEPLOY.md) (en la raíz de la rama `main`).

| Archivo | Para qué |
| --- | --- |
| `docker-compose.yml` | Producción: PostgreSQL 18 (`db`), `migraciones` (instala o actualiza la base y el rol `sgd_backend`) y `backend` |
| `.env.ejemplo` | Variables de producción, sin valores. Copiar a `.env` (no se sube a Git) |
| `respaldar.sh` | Respaldo diario de la base y de los archivos, juntos |
| `docker-compose.dev.yml` | Solo desarrollo: PostgreSQL en `localhost:5432` con las migraciones aplicadas |
