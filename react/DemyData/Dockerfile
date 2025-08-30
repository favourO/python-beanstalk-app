# ---------- build stage ----------
FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

# copy all sources
COPY . .

# build: Vite root is src/, outDir is ../dist → we’ll get /app/dist
RUN npm run build

# ---------- run stage ----------
FROM nginx:1.27-alpine
# copy the built app to nginx html
COPY --from=build /app/dist /usr/share/nginx/html
# nginx config with SPA fallback + health
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://localhost/health || exit 1
CMD ["nginx", "-g", "daemon off;"]
