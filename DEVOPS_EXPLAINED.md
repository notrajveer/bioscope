# DevOps Architecture & Engineering Guide: `bioscope-lite`

> **Audience:** Development, DevOps, and Engineering Team  
> **Repository:** [https://github.com/notrajveer/bioscope](https://github.com/notrajveer/bioscope)  
> **Image Registry:** [Docker Hub: `notrajveer/bioscope-lite`](https://hub.docker.com/r/notrajveer/bioscope-lite)  
> **Base Branch:** `main`  
> **Last Verified Commit:** `c58917c` (`"Add Docker multi-stage build and GitHub Actions CI/CD pipelines"`)

---

## 1. Executive Summary & Project Context

`bioscope-lite` is a pure client-side, interactive 3D biology education Single Page Application (SPA). It uses modern frontend technologies:
* **UI & Rendering:** React 19 (`createRoot`), Three.js via React Three Fiber (`@react-three/fiber`), `@react-three/drei`, 3Dmol, and GSAP.
* **Build Tool:** Vite 8.
* **Routing:** In-memory React state (`activeSection` within `src/components/workspace.jsx`). No server-side rendering (SSR) is utilized.
* **Quality Tooling:** `oxlint` (a high-performance Rust-based JavaScript/React linter).

### The DevOps Objective
The goal was to transform a raw client-side application into a **production-ready, containerized, and automated delivery system**. Specifically, the DevOps pipeline achieves:
1. **Zero-Configuration Deployment:** Anyone with Docker installed can run the entire 3D application in seconds with a single command without installing Node.js, Vite, or npm packages.
2. **Shift-Left Quality & Build Assurance:** Automated GitHub Actions run linters and production builds on every push and pull request before code can reach production.
3. **Automated Container Release Lifecycle:** High-speed, cached multi-stage Docker builds automatically build, tag, and publish production container images to Docker Hub upon merges to `main` and release tags.
4. **Optimized Web Delivery:** A hardened Nginx server provides gzip compression, client-side SPA routing fallback, and aggressive caching for heavy 3D assets (`.glb` files) and hashed JavaScript bundles.

---

## 2. Core DevOps Principles Applied in This Project

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 DEVELOPER WORKFLOW                     │
                  └──────────────────────────┬─────────────────────────────┘
                                             │ git push / pull_request
                                             ▼
                  ┌────────────────────────────────────────────────────────┐
                  │            CONTINUOUS INTEGRATION (ci.yml)             │
                  │  1. Checkout Repo (actions/checkout)                   │
                  │  2. Setup Node 22 + Global npm cache                   │
                  │  3. Deterministic Dependency Install (npm ci)          │
                  │  4. Fast-Fail Code Quality Gate (oxlint)               │
                  │  5. Production Build Verification (vite build)         │
                  └──────────────────────────┬─────────────────────────────┘
                                             │ on merge to main / v* tag
                                             ▼
                  ┌────────────────────────────────────────────────────────┐
                  │        CONTINUOUS DEPLOYMENT (docker-publish.yml)      │
                  │  1. Setup Buildx + GitHub Actions Cache (type=gha)     │
                  │  2. Authenticate to Docker Hub via GitHub Secrets      │
                  │  3. Multi-Stage Docker Build (Node Alpine -> Nginx)    │
                  │  4. Smart Tagging (:latest, :sha-xxx, :v1.0.0)         │
                  │  5. Push Image to Docker Hub Registry                  │
                  └──────────────────────────┬─────────────────────────────┘
                                             │ docker pull / docker run
                                             ▼
                  ┌────────────────────────────────────────────────────────┐
                  │            PRODUCTION RUNTIME (Nginx Alpine)           │
                  │  * Port 80 HTTP Static Serving                         │
                  │  * In-Memory Gzip Asset Compression                    │
                  │  * Immutable Caching (1y for /assets/, 30d for .glb)   │
                  │  * Single Page Application Fallback Routing            │
                  └────────────────────────────────────────────────────────┘
```

---

### Concept 1: Continuous Integration (CI) & Shift-Left Quality

* **What it is:** Continuous Integration automates the validation of code changes as soon as developers commit or open pull requests. "Shift-left" means catching bugs, syntax issues, and broken builds early in the lifecycle rather than in staging or production.
* **How it is applied here:**
  * **Strict Dependency Locking (`npm ci`):** Instead of running `npm install` (which can mutate `package-lock.json` or install non-deterministic minor/patch updates), CI runs `npm ci`. This ensures builds are identical across developer machines and remote runners.
  * **Ultra-Fast Linting (`oxlint`):** Rather than standard ESLint (which can take 15–30 seconds), `oxlint` runs in under 400 milliseconds across 50 files. It flags React anti-patterns (such as synchronous `setState` in `useEffect`) and syntax errors before the build step runs.
  * **Build Verification (`vite build`):** Validates that all TypeScript/JSX transformations, Three.js modules, and CSS imports bundle successfully into static files without missing imports or tree-shaking failures.
  * **Pipeline Caching (`actions/setup-node` with `cache: 'npm'`):** Avoids re-downloading identical npm packages across workflow runs, cutting CI execution time to ~20 seconds.

---

### Concept 2: Multi-Stage Containerization (Docker)

* **What it is:** Standard Docker builds often leave behind compilers, build tools, package managers, and gigabytes of intermediate files in the final image. Multi-stage builds use multiple `FROM` instructions, allowing the final stage to inherit only the production artifacts.
* **How it is applied here:**
  * **Stage 1 (`builder` with `node:22-alpine`):**
    * Copies `package.json` and `package-lock.json` first.
    * Runs `npm ci`.
    * Copies source files and runs `npm run build`, producing the production static folder `/app/dist`.
  * **Stage 2 (`runtime` with `nginx:stable-alpine`):**
    * Discards Node 22, npm, `node_modules`, and all source code.
    * Copies only `/app/dist` from the `builder` stage into `/usr/share/nginx/html`.
    * Copies the custom `nginx.conf`.
* **The DevOps Impact:**
  * **Image Size Reduction:** Final image payload is only **~46.5 MB**, compared to 600MB–1GB+ if Node and `node_modules` were retained.
  * **Security Hardening:** The attack surface is drastically minimized. The final container has no Node runtime, no package installer, and no build toolchains that attackers could exploit.
  * **Layer Caching:** By copying `package.json` and `package-lock.json` *before* the application code (`COPY . .`), Docker caches the expensive `npm ci` layer. When source code changes, Docker skips dependency installation completely.

---

### Concept 3: Context Boundary Isolation (`.dockerignore`)

* **What it is:** When Docker builds an image, the client sends all files from the current directory (the "build context") to the Docker daemon. A `.dockerignore` file prevents unwanted files from entering the build context.
* **How it is applied here:**
  * Excludes host `node_modules/` and local `dist/`.
  * Excludes `.git/`, `.github/`, local environment files (`.env`), and OS metadata (`.DS_Store`, `Thumbs.db`).
* **Why this is critical for Vite 8:**
  * Vite 8 relies on native compiled binaries (such as Rolldown and Lightning CSS). If a developer on Windows copies their local host `node_modules/` into a Linux-based Alpine container, the native binaries will mismatch and crash. Excluding `node_modules/` ensures clean Linux native binaries are compiled inside Alpine.

---

### Concept 4: Production Web Server Engineering (`nginx.conf`)

* **What it is:** SPAs require specific web server rules because routing is handled by the browser's JavaScript runtime, not server-side directories.
* **How it is applied here:**
  * **SPA Fallback Routing:**
    ```nginx
    location / {
        try_files $uri $uri/ /index.html;
    }
    ```
    If a user navigates to a deep link or refreshes the page, Nginx checks if the file exists; if not, it returns `/index.html` with an HTTP 200 rather than an HTTP 404.
  * **On-the-Fly Gzip Compression:** Compresses text, JavaScript, CSS, JSON, and SVGs, reducing transfer size across the network by up to 70%.
  * **Tiered Caching Policy:**
    * **Vite Assets (`/assets/`):** Cache duration `1y` with `Cache-Control: "public, immutable"`. Vite uses content hashing (e.g., `index-uuyBgkWE.js`). If code changes, the filename changes, so browsers can safely cache old assets forever.
    * **3D Anatomy Assets (`/anatomy/`):** Cache duration `30d` with `Cache-Control: "public"`. Prevents repeated downloading of multi-megabyte `.glb` models (`heart`, `anatomy-male`, `anatomy-female`).

---

### Concept 5: Continuous Deployment & Automated Image Publishing

* **What it is:** Continuous Deployment automatically packages and releases verified code to a registry or environment without manual intervention.
* **How it is applied here:**
  * **Event Separation:** Build & Publish triggers only on pushes to `main` and release tags (`v*.*.*`). It is deliberately excluded from `pull_request` triggers to prevent malicious PRs from accessing secrets or pushing poisoned images.
  * **Docker Buildx & GitHub Actions Cache (`type=gha`):** Uses the BuildKit engine with GitHub Actions remote layer cache (`mode=max`). Rebuilds in CI reuse cached layers directly from GitHub storage.
  * **Dynamic Multi-Tagging (`docker/metadata-action`):**
    * Merges to `main` publish:
      * `:latest`
      * `:sha-<commit-sha>` (traceability to exact git commit)
    * Tag releases (`v1.0.0`) publish:
      * `:1.0.0` (exact semantic version)
      * `:1.0` (minor version pointer)
      * `:latest`
      * `:sha-<commit-sha>`
  * **Credential Safety:** Docker Hub credentials (`DOCKER_USERNAME` and `DOCKER_TOKEN`) are securely stored as GitHub Action Secrets. Minimal repository permissions (`permissions: contents: read`) are enforced.

---

## 3. End-to-End Walkthrough: What Happens in the Project

### Scenario A: A Developer Submits a Pull Request
1. Developer branches off `main`, makes a UI change in `src/scenes/cell.jsx`, and opens a PR.
2. GitHub Actions detects the PR targeting `main` and triggers `.github/workflows/ci.yml`.
3. An `ubuntu-latest` runner initializes:
   - Checks out the branch.
   - Installs Node 22 and checks out cached global npm modules.
   - Runs `npm ci` in ~15–20s.
   - Executes `npm run lint` (`oxlint`). If lint errors exist, the workflow halts immediately and fails the PR check.
   - Executes `npm run build` (`vite build`). If any import is missing or bundling fails, the check fails.
4. If successful, GitHub marks the PR check green. Code review proceeds safely.

### Scenario B: The PR is Merged into `main`
1. The PR is merged. A `push` event on branch `main` occurs.
2. Two workflows trigger concurrently:
   - **`ci.yml`**: Runs the lint and build regression check on `main`.
   - **`docker-publish.yml`**:
     - Connects securely to Docker Hub with `DOCKER_USERNAME` and `DOCKER_TOKEN`.
     - Invokes Docker Buildx with GitHub Actions caching.
     - Runs the multi-stage `Dockerfile`.
     - Generates tags: `notrajveer/bioscope-lite:latest` and `notrajveer/bioscope-lite:sha-<hash>`.
     - Pushes the image layers to Docker Hub.
3. The new container image is immediately available globally on Docker Hub.

### Scenario C: Creating an Official Versioned Release
1. A release manager creates a semantic version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. `docker-publish.yml` triggers on `tags: ['v*.*.*']`.
3. It builds the container and pushes:
   - `notrajveer/bioscope-lite:1.0.0`
   - `notrajveer/bioscope-lite:1.0`
   - `notrajveer/bioscope-lite:latest`
   - `notrajveer/bioscope-lite:sha-<hash>`
4. Production clusters can now deploy `:1.0.0` with guaranteed immutability.

---

## 4. Configuration Files Reference & Annotations

### 1. `.dockerignore`
Controls what gets sent to the Docker build daemon:
```dockerignore
# Dependencies & local build artifacts (prevents OS binary mismatch)
node_modules
dist

# Git & GitHub Actions files (not needed inside container)
.git
.gitignore
.github

# Local environment files & logs (prevents credential leaks)
.env
.env.*
*.log
npm-debug.log*

# Editor & OS files
.vscode
.idea
.DS_Store
Thumbs.db

# Build docs & docker manifests
Dockerfile
.dockerignore
README.md
```

### 2. `Dockerfile`
Multi-stage build definition:
```dockerfile
# Stage 1: Build the Vite application with modern Node 22 on lightweight Alpine Linux
FROM node:22-alpine AS builder

WORKDIR /app

# Cache layer: Only re-install dependencies if package files change
COPY package.json package-lock.json ./
RUN npm ci

# Copy remaining source code and compile production assets to /app/dist
COPY . .
RUN npm run build

# Stage 2: Serve static files with lightweight, hardened Nginx
FROM nginx:stable-alpine

# Remove default boilerplate HTML
RUN rm -rf /usr/share/nginx/html/*

# Inject custom SPA configuration and copy compiled distribution from builder stage
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

# Keep Nginx running in foreground
CMD ["nginx", "-g", "daemon off;"]
```

### 3. `nginx.conf`
Production web server configuration:
```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip Compression for minimal wire transfer size
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        image/svg+xml;

    # Immutable 1-year caching for content-hashed Vite JS/CSS bundles
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 30-day public caching for static 3D GLB anatomy models
    location /anatomy/ {
        expires 30d;
        add_header Cache-Control "public";
    }

    # SPA Fallback: guarantees client-side routes do not 404 on refresh
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 4. `.github/workflows/ci.yml`
Automated validation gate:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  lint-and-build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Setup Node.js 22 with npm cache
        uses: actions/setup-node@v7
        with:
          node-version: 22
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint with oxlint
        run: npm run lint

      - name: Build production bundle
        run: npm run build
```

### 5. `.github/workflows/docker-publish.yml`
Automated container deployment:
```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    tags: ['v*.*.*']

permissions:
  contents: read

jobs:
  docker:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Log in to Docker Hub
        uses: docker/login-action@v4
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Extract Docker metadata (tags & labels)
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ${{ secrets.DOCKER_USERNAME }}/bioscope-lite
          tags: |
            type=raw,value=latest,enable={{is_default_branch}}
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Build and push Docker image
        uses: docker/build-push-action@v7
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## 5. Verification & Health Check Results

| Check / Metric | Status | Result / Details |
| :--- | :--- | :--- |
| **Git Working Tree** | Verified Clean | Clean on `origin/main` (`c58917c`). Stray `workflows/` directory removed. |
| **Dependency Installation** | Passed | `npm ci` completed cleanly (94 packages, 0 vulnerabilities). |
| **Linter (`oxlint`)** | Passed | 50 files scanned across 104 rules in 339ms (0 errors, 1 non-blocking warning). |
| **Vite Production Build** | Passed | 2,686 modules transformed in 3.51s, static output generated in `dist/`. |
| **CI Workflow (`ci.yml`)** | Passed | CI run #1 passed in 21s on GitHub Actions. |
| **CD Workflow (`docker-publish.yml`)** | Passed | Docker Publish run #1 passed in 1m 35s on GitHub Actions. |
| **Docker Image Size** | Optimized | Image content size: **46.5 MB** (Node runtime & `node_modules` discarded). |
| **Port & Routing Exposure** | Verified | Port 80 exposed, mapped to port 8080 locally; tested with SPA fallback. |

---

## 6. How Teammates Can Run and Use This Project

### Option 1: One-Click Quick Run (`run.bat`)
A self-contained helper script is provided in the repository root:
* **Double-click `run.bat`** (or execute `.\run.bat` in the terminal).
  * Validates Docker Desktop is running.
  * Launches the container on `http://localhost:8080`.
  * Automatically opens your default web browser to the application.
  * When you are done, simply press any key in the console window to stop the container cleanly.

### Option 2: Docker Desktop GUI (No Command Line Needed)
1. Open **Docker Desktop** and navigate to **Images** -> **Local**.
2. Find `bioscope-lite` (tag: `local`).
3. Click the **Run (▶️)** button.
4. Expand **Optional settings**, set **Host port** to `8080`, and click **Run**.
5. Switch to **Containers** in Docker Desktop and click the `8080:80` port link to open in your browser.

### Option 3: Terminal / Docker CLI
```bash
# Run locally built image:
docker run -d -p 8080:80 --name bioscope-local bioscope-lite:local

# Or use convenience npm scripts:
npm run docker:run   # Start
npm run docker:stop  # Stop

# Or pull and run directly from Docker Hub:
docker run -d -p 8080:80 --name bioscope notrajveer/bioscope-lite:latest
```
Visit `http://localhost:8080` in your browser.

### Option 4: Local Frontend Development (Without Docker)
```bash
npm install
npm run dev      # Starts Vite dev server with hot reload on localhost:5173
npm run lint     # Runs oxlint
npm run build    # Tests production bundling
```

---

## 7. Recommended Next Steps for the Team

1. **Tag a Semantic Version:** Test the semver release trigger on GitHub Actions:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   Verify that tags `:1.0.0` and `:1.0` appear in Docker Hub alongside `:latest`.
2. **Add Legacy Files to `.dockerignore`:** Add `BioScope (1).html` and `*.zip` to `.dockerignore` to keep the Docker build context even leaner.
3. **Automated End-to-End Testing (Optional):** When interactive 3D component tests are written (e.g. using Playwright or Vitest), add a test job step into `.github/workflows/ci.yml` before `npm run build`.
