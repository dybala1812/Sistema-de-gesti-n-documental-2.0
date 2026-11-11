import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Imagen Docker liviana: .next/standalone trae solo lo necesario (ver Dockerfile).
  output: "standalone",
  // Nunca copiar adjuntos reales, logs ni secretos a .next/standalone.
  outputFileTracingExcludes: {
    "/*": ["archivos_sgd/**", "*.log", ".env*", "tests/**", "Dockerfile"],
  },
  experimental: {
    agentFeedback: true,
    // middleware.ts (CORS) hace que Next guarde el cuerpo de cada petición en memoria, con un tope de
    // 10 MB por defecto: una subida mayor llegaba cortada y fallaba con 500. El máximo por archivo es
    // 50 MB (parámetro tamano_maximo_archivo_mb), más lo que agrega el formulario multipart.
    proxyClientMaxBodySize: "60mb",
  },
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
