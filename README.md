# bioscope-lite

[![CI](https://github.com/notrajveer/bioscope/actions/workflows/ci.yml/badge.svg)](https://github.com/notrajveer/bioscope/actions/workflows/ci.yml)
[![Docker Publish](https://github.com/notrajveer/bioscope/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/notrajveer/bioscope/actions/workflows/docker-publish.yml)

An interactive 3D biology education web application built with React 19, Vite 8, Three.js (React Three Fiber), and GSAP.

---

## 🚀 Tutorial: How to Run This Project Yourself

Choose whichever method is easiest for you:

### Method 1: One-Click Quick Run (Easiest for Windows)

* **Double-click `run.bat`** in File Explorer (or run `.\run.bat` in terminal).
* **What it does automatically:**
  1. Checks that Docker Desktop is running.
  2. Starts the production container on port `8080`.
  3. **Opens your browser automatically to [http://localhost:8080](http://localhost:8080)**.
  4. Keeps a small window open: simply **press any key** in that window when you are done to automatically stop the container and clean up!

---

### Method 2: Using the Docker Desktop GUI (Visual)

1. Open **Docker Desktop** and click **Images** in the left sidebar.
2. Under the **Local** tab, find `bioscope-lite` (tag: `local`).
3. Hover over it and click the **Run / Play (▶️)** button under the **Actions** column.
4. In the pop-up modal:
   - Click **Optional settings** (drop-down).
   - Under **Host port**, type `8080`.
   - Set **Container name** to `bioscope-local` (optional).
   - Click **Run**.
5. Once running, go to **Containers** in the left sidebar and click `8080:80` (or open [http://localhost:8080](http://localhost:8080) in your browser).
6. To stop: Click the **Stop (⏹️)** square icon or trash bin next to the container in Docker Desktop.

---

### Method 3: Using the Terminal / Command Line (Docker)

Ensure Docker Desktop is open and run:

```bash
# 1. Start the container
docker run -d -p 8080:80 --name bioscope-local bioscope-lite:local

# 2. Open in your browser
# Visit: http://localhost:8080

# 3. Stop the container when you are done
docker rm -f bioscope-local
```

> **Using npm scripts:** You can also run `npm run docker:run` to start and `npm run docker:stop` to stop!

If you want to pull the officially published image from Docker Hub instead of building locally:
```bash
docker run -d -p 8080:80 --name bioscope-hub notrajveer/bioscope-lite:latest
```

---

### Method 4: Local Development (Without Docker)

If you are developing or modifying the React/Three.js source code:

```bash
# 1. Install dependencies
npm install

# 2. Start Vite development server
npm run dev
```

Visit the local dev server link shown in your terminal (typically `http://localhost:5173`).

#### Available npm Scripts:
- `npm run dev` - Start the Vite development server with Hot Module Replacement (HMR)
- `npm run lint` - Lint the codebase with `oxlint`
- `npm run build` - Build the production static bundle to `dist/`
- `npm run preview` - Preview the built `dist/` bundle locally
- `npm run docker:run` - Start the production Docker container
- `npm run docker:stop` - Stop the production Docker container

---

## 🐳 Docker Architecture

The project uses a multi-stage `Dockerfile`:
- **Stage 1 (`node:22-alpine`):** Installs dependencies deterministically (`npm ci`) and builds the static assets with Vite 8.
- **Stage 2 (`nginx:stable-alpine`):** Discards Node and all source code, serving only `dist/` through a custom `nginx.conf` that provides:
  - SPA fallback routing (`try_files $uri $uri/ /index.html;`)
  - Gzip compression for all web assets
  - Long-term caching (1 year immutable for hashed bundles, 30 days for `.glb` 3D anatomy models)

---

## ⚙️ CI/CD Pipelines

- **Continuous Integration (`.github/workflows/ci.yml`)**: Triggers on every push and pull request to `main`. Runs `npm ci`, code quality checks with `oxlint`, and verifies `vite build`.
- **Docker Publish (`.github/workflows/docker-publish.yml`)**: Triggers on pushes to `main` and version tags (`v*.*.*`). Uses Docker Buildx with GitHub Actions caching to build and push tagged images (`:latest`, semver tags, and `:sha-...`) to Docker Hub.

For full architectural details, see [DEVOPS_EXPLAINED.md](./DEVOPS_EXPLAINED.md).
