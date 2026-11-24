# bioscope-lite

[![CI](https://github.com/notrajveer/bioscope/actions/workflows/ci.yml/badge.svg)](https://github.com/notrajveer/bioscope/actions/workflows/ci.yml)
[![Docker Publish](https://github.com/notrajveer/bioscope/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/notrajveer/bioscope/actions/workflows/docker-publish.yml)

An interactive 3D biology education web application built with React 19, Vite 8, Three.js (React Three Fiber), and GSAP — fully automated with Docker multi-stage containerization and GitHub Actions CI/CD.

---

## 🎓 Quick Run for Professors & Evaluators (Zero-Setup Remote Run)

If you have Docker installed on your computer (Windows, macOS, or Linux), **you do not need Node.js, npm, or to clone the code**. You can run the verified production container with a single command:

```bash
docker run -d -p 8080:80 --name bioscope notrajveer/bioscope-lite:latest
```

Open your browser to: **[http://localhost:8080](http://localhost:8080)**

When you are finished evaluating, stop and clean up the container with:
```bash
docker rm -f bioscope
```

---

## 🗺️ DevOps Flow of Work & Architecture

The following flowchart illustrates the step-by-step lifecycle of how this project was designed, containerized, automated, and distributed:

```
[ STEP 1: APPLICATION DEVELOPMENT ]
  * Interactive 3D Biology SPA (React 19, Vite 8, Three.js, GSAP)
  * Heavy 3D GLB Models & Client-side State Routing
                  │
                  ▼
[ STEP 2: CODE QUALITY & VALIDATION ]
  * Rust-based linter (oxlint) scans 50 files in <400ms
  * Production bundle compilation verified via 'vite build'
                  │
                  ▼
[ STEP 3: CONTAINERIZATION ARCHITECTURE ]
  * .dockerignore filters host node_modules, logs, and legacy files
  * Dockerfile Stage 1: 'node:22-alpine' builder installs dependencies (npm ci) and builds dist/
  * Dockerfile Stage 2: 'nginx:stable-alpine' runtime copies ONLY dist/ and nginx.conf
  * Image size optimized from ~1 GB down to 46.5 MB
                  │
                  ▼
[ STEP 4: PRODUCTION SERVER HARDENING (nginx.conf) ]
  * SPA Fallback Routing: 'try_files $uri $uri/ /index.html' prevents 404s on refresh
  * On-the-fly Gzip compression for JS, CSS, JSON, and SVG assets
  * Tiered HTTP Caching: 1y immutable for /assets/, 30d for /anatomy/ 3D models
                  │
                  ▼
[ STEP 5: CONTINUOUS INTEGRATION (ci.yml) ]
  * Triggers on every push & pull request to 'main'
  * Minimal permissions (contents: read)
  * Node 22 setup with global npm cache keyed to package-lock.json
  * Automated gate: checkout -> npm ci -> oxlint -> vite build
                  │
                  ▼
[ STEP 6: CONTINUOUS DEPLOYMENT (docker-publish.yml) ]
  * Triggers on merges to 'main' and version tags ('v*.*.*')
  * Authenticates to Docker Hub via GitHub Actions Secrets (DOCKER_USERNAME, DOCKER_TOKEN)
  * Docker Buildx with remote GitHub Actions cache (cache-from/to: type=gha, mode=max)
  * Automated smart tagging: ':latest', ':sha-<hash>', and semver ':1.0.0'
  * Publishes image to Docker Hub (notrajveer/bioscope-lite)
                  │
                  ▼
[ STEP 7: DEVELOPER EXPERIENCE & ZERO-SETUP DISTRIBUTION ]
  * Single-click 'run.bat' for local execution with automated browser launch & cleanup
  * Universal remote execution: 'docker run -d -p 8080:80 notrajveer/bioscope-lite:latest'
```

---

## 📖 How the DevOps Work Was Executed (Step-by-Step Narrative)

1. **Requirement Analysis & Baseline Setup:**
   * Started with a pure client-side 3D SPA. Identified requirements for reproducible deployment, environment parity (Windows dev host to Linux production container), and automated quality gates.
2. **Eliminating Host-to-Container Incompatibilities:**
   * Because Vite 8 uses native Rust binaries (Rolldown & Lightning CSS), copying host `node_modules` from Windows into a Linux container crashes. Configured `.dockerignore` to strictly prevent `node_modules`, `.git`, environment files, and legacy artifacts from entering the build context.
3. **Designing the Multi-Stage Dockerfile:**
   * Selected `node:22-alpine` because Node 20 reached End-of-Life.
   * Structured Docker layers so `package.json` and `package-lock.json` copy first, caching `npm ci`.
   * Switched to `nginx:stable-alpine` in Stage 2, completely stripping the Node runtime and dependencies for a secure 46.5 MB container.
4. **Hardening the Web Server (`nginx.conf`):**
   * Configured `try_files` so client-side in-memory routes reload cleanly without 404s.
   * Implemented Gzip compression and long-term immutable caching for hashed assets, with dedicated 30-day caching for heavy 3D `.glb` anatomy models.
5. **Building the GitHub Actions CI Pipeline (`ci.yml`):**
   * Configured automated triggers on pushes and PRs to `main`.
   * Used `oxlint` for high-speed static analysis and verified production bundling (`vite build`) to fail fast before broken code can merge.
6. **Automating the Release Pipeline (`docker-publish.yml`):**
   * Integrated Docker Hub credentials via repository secrets.
   * Employed Docker Buildx with GitHub Actions caching (`type=gha`) for fast builds and automated tagging (`latest`, semver tags, and commit SHAs).
7. **Local Verification & Experience Optimization:**
   * Cleaned up untracked legacy files (`BioScope (1).html` and `.zip`).
   * Created a single-click launcher (`run.bat`) that verifies Docker, launches the container on port `8080`, launches the browser, and cleanly stops the container upon keypress.

---

## 🚀 How to Run the Project Locally

Choose whichever method fits your environment:

### Method 1: One-Click Quick Run (Windows)

* **Double-click `run.bat`** in File Explorer (or run `.\run.bat` in your terminal).
* **What it does automatically:**
  1. Checks that Docker Desktop is running.
  2. Starts the production container on port `8080`.
  3. **Opens your browser automatically to [http://localhost:8080](http://localhost:8080)**.
  4. Keeps a small console window open: simply **press any key** when you are done to automatically stop and clean up the container!

---

### Method 2: Docker Desktop GUI (Visual)

1. Open **Docker Desktop** and click **Images** in the left sidebar.
2. Under the **Local** tab, find `bioscope-lite` (tag: `local`).
3. Click the **Run / Play (▶️)** button under the **Actions** column.
4. Under **Optional settings**, set **Host port** to `8080` and click **Run**.
5. Switch to **Containers** in Docker Desktop and click `8080:80` (or visit [http://localhost:8080](http://localhost:8080)).
6. To stop: Click the **Stop (⏹️)** button next to the container.

---

### Method 3: Using the Terminal / Command Line (Docker)

```bash
# Start the container
docker run -d -p 8080:80 --name bioscope-local bioscope-lite:local

# Open http://localhost:8080 in your browser

# Stop and remove the container when done
docker rm -f bioscope-local
```

*(You can also run `npm run docker:run` to start and `npm run docker:stop` to stop).*

---

### Method 4: Local Frontend Development (Without Docker)

```bash
# 1. Install dependencies
npm install

# 2. Start Vite development server
npm run dev
```

Visit the local dev server link shown in your terminal (typically `http://localhost:5173`).

#### Available npm Scripts:
- `npm run dev` - Start Vite development server with Hot Module Replacement (HMR)
- `npm run lint` - Lint codebase with `oxlint`
- `npm run build` - Compile production static bundle to `dist/`
- `npm run preview` - Preview built `dist/` bundle locally
- `npm run docker:run` - Start production Docker container
- `npm run docker:stop` - Stop production Docker container
- `npm run docker:build` - Build local Docker image

---

## 📚 Detailed Documentation

For a comprehensive deep dive into every DevOps concept used (multi-stage builds, layer caching, Nginx tuning, CI/CD security, and step-by-step lifecycle analysis), refer to:
👉 **[DEVOPS_EXPLAINED.md](./DEVOPS_EXPLAINED.md)**
