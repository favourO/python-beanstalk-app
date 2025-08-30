// vite.config.ts (or .js)
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath, URL } from "node:url";

export default defineConfig({
  // IMPORTANT: your index.html is inside src/
  root: "src",

  // in dev, proxy /api to your backend
  server: {
    proxy: {
      "/api": {
        target: "http://localhost:8000",
        changeOrigin: true,
        secure: false,
      },
    },
  },

  // in prod, we build out to ../dist so it sits next to src/
  build: {
    outDir: "../dist",
    emptyOutDir: true,
  },

  // if you keep public/ at repo root, point Vite to it explicitly
  publicDir: fileURLToPath(new URL("./public", import.meta.url)),

  plugins: [react(), tailwindcss()],
});