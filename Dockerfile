# Stage 1: Build
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* bun.lockb* ./

RUN npm install

COPY . .

RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:stable-alpine

# Fix CVE-2026-22184: upgrade zlib to patched version 1.3.2-r0
# Fix CVE-2026-40200: upgrade musl to patched version 1.2.5-r23
RUN apk add --no-cache zlib=1.3.2-r0 musl=1.2.5-r23 musl-utils=1.2.5-r23

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]


