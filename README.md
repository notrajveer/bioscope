# bioscope-lite

[![CI](https://github.com/notrajveer/bioscope/actions/workflows/ci.yml/badge.svg)](https://github.com/notrajveer/bioscope/actions/workflows/ci.yml)
[![Docker Publish](https://github.com/notrajveer/bioscope/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/notrajveer/bioscope/actions/workflows/docker-publish.yml)

An interactive 3D biology education web application built with React 19, Vite 8, Three.js (React Three Fiber), and GSAP.

## Local Development

```bash
npm install
npm run dev
```

### Scripts

- `npm run dev` - Start the Vite development server
- `npm run lint` - Lint the codebase with oxlint
- `npm run build` - Build production static assets to `dist/`
- `npm run preview` - Preview the production build locally

## Docker

Built with a multi-stage `Dockerfile` (Node 22 Alpine build stage -> Nginx Alpine serve stage) and a custom `nginx.conf` for SPA fallback routing, gzip compression, and asset caching.

### Build and Run Locally

```bash
docker build -t bioscope-lite .
docker run -d -p 8080:80 --name bioscope-lite bioscope-lite
```

Open `http://localhost:8080`. Stop and remove the container when done:

```bash
docker rm -f bioscope-lite
```

### Pull from Docker Hub

```bash
docker run -d -p 8080:80 notrajveer/bioscope-lite:latest
```

## CI/CD

- **CI (`.github/workflows/ci.yml`)**: Runs on pushes and pull requests to `main`. Installs dependencies with `npm ci`, runs `oxlint`, and verifies the Vite production build.
- **Docker Publish (`.github/workflows/docker-publish.yml`)**: Runs on pushes to `main` and version tags (`v*.*.*`). Uses Docker Buildx with GitHub Actions layer caching to build and push tagged images (`latest`, semver, and commit SHA) to Docker Hub.
