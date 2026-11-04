# Backend SGD · Archivo Central — imagen de producción (Next.js standalone).
# Construir:  docker build -t sgd-backend .
# Ejecutar:   con la base local, desde despliegue/: docker compose up -d --build (ver despliegue/README.md).

FROM node:24-alpine AS dependencias
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:24-alpine AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=dependencias /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:24-alpine AS ejecucion
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    RAIZ_ARCHIVOS=/data/archivos
# Usuario sin privilegios; los archivos de los documentos van en un volumen (nunca dentro de la imagen).
RUN addgroup -S sgd && adduser -S sgd -G sgd && mkdir -p /data/archivos && chown -R sgd:sgd /data
COPY --from=build --chown=sgd:sgd /app/.next/standalone ./
COPY --from=build --chown=sgd:sgd /app/.next/static ./.next/static
COPY --from=build --chown=sgd:sgd /app/public ./public
USER sgd
EXPOSE 3000
VOLUME ["/data/archivos"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/salud >/dev/null || exit 1
CMD ["node", "server.js"]
