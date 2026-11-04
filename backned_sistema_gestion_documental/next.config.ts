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
