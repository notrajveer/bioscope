# Stage 1: Build the Vite application
FROM node:22-alpine AS builder

WORKDIR /app

# Copy lockfile and manifest first to maximize Docker layer caching
COPY package.json package-lock.json ./
RUN npm ci

# Copy remaining source files and build static assets into /app/dist
COPY . .
RUN npm run build

# Stage 2: Serve static files with lightweight Nginx
FROM nginx:stable-alpine

# Clear default Nginx static files
RUN rm -rf /usr/share/nginx/html/*

# Copy custom SPA Nginx config and built Vite output
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

# Run Nginx in the foreground so the container stays alive
CMD ["nginx", "-g", "daemon off;"]
