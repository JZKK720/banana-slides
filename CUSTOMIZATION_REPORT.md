# Banana Slides - Port & Expose Configuration Report

**Report Generated:** February 2, 2026  
**Project:** Banana Slides  
**Scope:** Port and expose settings across all services

---

## 📋 Executive Summary

This report documents all exposed ports and host port configurations in the Banana Slides application. The project uses a modular architecture with backend (Flask), frontend (React/Vite), and containerized services, each with specific port configurations.

**Total Services:** 2 (Backend + Frontend)  
**Exposed Ports:** 3 (5101 for backend, 3031 for frontend, 80 for nginx)

---

## 🔌 Port Configuration Details

### 0. **Local LLM Services (Optional)**

#### Ollama Service
| Component | Address | Port | Purpose |
|-----------|---------|------|---------|
| Ollama API | `host.docker.internal` | `11434` | Local text/vision models |
| Docker Access | `host.docker.internal:11434` | N/A | From container to host |

**Configuration:**
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_BASE=http://host.docker.internal:11434/v1
OPENAI_API_KEY=ollama
OLLAMA_TEXT_MODEL=llama2
OLLAMA_IMAGE_MODEL=llava
```

#### LM Studio Service
| Component | Address | Port | Purpose |
|-----------|---------|------|---------|
| LM Studio API | `127.0.0.1` | `14321` | Local model serving |
| API Endpoint | `/api/v1/chat` | N/A | Chat completions |

**Configuration:**
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_BASE=http://127.0.0.1:14321/api/v1
OPENAI_API_KEY=your-token-if-required
LM_STUDIO_TEXT_MODEL=ibm/granite-4-micro
```

**Example API Call:**
```bash
curl http://127.0.0.1:14321/api/v1/chat \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ibm/granite-4-micro",
    "input": "Your prompt here"
  }'
```

---

### 1. **Backend Service**

#### Backend Port Mapping
| Component | Port Type | Default Port | Configurable | Location |
|-----------|-----------|--------------|--------------|----------|
| Flask App (Host) | Host Port | `5101` | ✅ Yes (`BACKEND_PORT` env var) | docker-compose files |
| Flask App (Container) | Container Port | `5000` | ❌ Fixed | Dockerfile / app.py |
| Health Check | Container Port | `5000` | ❌ Fixed | docker-compose files |

#### Files Involved:
- **[backend/app.py](backend/app.py#L244-L267)** - Backend server entry point
  - Host: `0.0.0.0` (listens on all interfaces)
  - Port: `5000` (fixed inside container, configurable on host via `BACKEND_PORT` env var)
  - Debug mode: Determined by `FLASK_ENV` environment variable

- **[docker-compose.yml](docker-compose.yml)** - Development compose file
  ```yaml
  ports:
    - "${BACKEND_PORT:-5101}:5000"
  ```
  - Host port controlled by `BACKEND_PORT` (defaults to 5101)
  - Container port fixed at 5000
  - Health check uses fixed container port: `http://localhost:5000/health`

- **[docker-compose.prod.yml](docker-compose.prod.yml)** - Production compose file
  ```yaml
  ports:
    - "${BACKEND_PORT:-5101}:5000"
  ```
  - Same configuration as development

- **[backend/config.py](backend/config.py)** - Flask configuration
  - CORS configuration: Defaults to `http://localhost:3000`
  - No hardcoded port binding here (handled in app.py)

#### Environment Variables:
| Variable | Purpose | Default | Required |
|----------|---------|---------|----------|
| `BACKEND_PORT` | Host port mapping | `5000` | ❌ No |
| `FLASK_ENV` | Environment mode | `development` | ❌ No |
| `IN_DOCKER` | Docker environment flag | `0` | ❌ No |

---

### 2. **Frontend Service**

#### Frontend Port Mapping
| Component | Port Type | Default Port | Configurable | Location |
|-----------|-----------|--------------|--------------|----------|
| Vite Dev Server | Host Port | `3031` | ❌ Fixed | vite.config.ts |
| Nginx (Production) | Container Port | `80` | ❌ Fixed | Dockerfile |
| Docker Mapping | Host Port | `3031` | ❌ Fixed | docker-compose files |

#### Files Involved:
- **[frontend/vite.config.ts](frontend/vite.config.ts)** - Vite development configuration
  ```typescript
  server: {
    port: 3031,
    host: true,  // Listen on all interfaces
    proxy: {
      '/api': backendUrl,    // Routes to backend
      '/files': backendUrl,  // Routes to backend
      '/health': backendUrl, // Routes to backend
    }
  }
  ```
  - Dev server port: `3031` (fixed)
  - Host: `true` (listens on all interfaces)
  - Backend proxy routes to `BACKEND_PORT` (reads from .env)

- **[frontend/Dockerfile](frontend/Dockerfile)** - Frontend container
  ```dockerfile
  EXPOSE 80
  ```
  - Nginx exposed port: `80` (fixed)
  - Nginx is the production server

- **[docker-compose.yml](docker-compose.yml)** - Frontend service mapping
  ```yaml
  ports:
    - "3031:80"
  ```
  - Host port: `3031` (fixed)
  - Container port: `80`
  - Depends on backend service

- **[docker-compose.prod.yml](docker-compose.prod.yml)** - Same as development

#### Environment Variables:
| Variable | Purpose | Default | Required |
|----------|---------|---------|----------|
| `BACKEND_PORT` | Backend port for proxy | `5000` | ❌ No |

---

### 3. **Health Check Endpoints**

| Service | Endpoint | Port | Protocol | Location |
|---------|----------|------|----------|----------|
| Backend | `/health` | 5000 | HTTP | Backend API |
| Frontend | `/` | 3000 | HTTP | Nginx (via docker-compose) |

#### Health Check Configuration (Backend):
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

---

## 🏠 Local LLM Services (Optional)

### Ollama Configuration
| Component | Address | Port | Purpose |
|-----------|---------|------|---------|
| Ollama API | `host.docker.internal` | `11434` | Local text/vision models |
| Text Model | llama2 | N/A | Text generation |
| Vision Model | llava | N/A | Image understanding |

**Setup:**
```bash
docker run -d -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
ollama pull llama2
ollama pull llava
```

**Enable in .env:**
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_BASE=http://host.docker.internal:11434/v1
OPENAI_API_KEY=ollama
OLLAMA_TEXT_MODEL=llama2
OLLAMA_IMAGE_MODEL=llava
```

### LM Studio Configuration
| Component | Address | Port | Purpose |
|-----------|---------|------|---------|
| LM Studio API | `127.0.0.1` | `14321` | Local model server |
| Default Model | ibm/granite-4-micro | N/A | Text generation |
| API Endpoint | `/api/v1/chat` | N/A | Chat completions |

**Download & Setup:**
- Download from: https://lmstudio.ai/
- Run locally on Windows/Mac/Linux
- Accessible at: `http://127.0.0.1:14321`

**Enable in .env:**
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_BASE=http://127.0.0.1:14321/api/v1
OPENAI_API_KEY=your-token-if-required
LM_STUDIO_TEXT_MODEL=ibm/granite-4-micro
```

**API Example:**
```bash
curl http://127.0.0.1:14321/api/v1/chat \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ibm/granite-4-micro",
    "input": "Write a short haiku about sunrise."
  }'
```

### Local Vision & OCR Models
| Service | Endpoint | Status | Purpose |
|---------|----------|--------|---------|
| Ollama Vision | `host.docker.internal:11434` | Optional | Image captioning, analysis |
| PaddleOCR | `localhost:8000` | Optional | Text extraction from images |
| Tesseract | `/usr/bin/tesseract` | Optional | Local OCR engine |

---

## 📊 Network Architecture

```
┌─────────────────────────────────────────────────────┐
│              Host Machine                           │
│                                                     │
│  http://localhost:3031 ◄──►  http://localhost:5101 │
│  (Frontend - Nginx)            (Backend - Flask)    │
│        │                              │              │
│        └──────────────────┬───────────┘              │
│                           │                          │
│  ┌─────────────────────────────────────────────────┐ │
│  │     Docker Network: banana-slides-network       │ │
│  │                                                  │ │
│  │  ┌──────────────────┐  ┌──────────────────────┐ │ │
│  │  │ Frontend (Nginx) │  │ Backend (Flask)      │ │ │
│  │  │ Port: 80         │  │ Port: 5000           │ │ │
│  │  │ Host: 3031:80    │  │ Host: $BACKEND_PORT  │ │ │
│  │  └──────────────────┘  │     :5000            │ │ │
│  │        │                └──────────────────────┘ │ │
│  │        │                       │                 │ │
│  │        └───────── /api proxy ──┘                 │ │
│  │                                                  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 🔧 Configuration Methods

### Method 1: Environment Variables (.env file)
```bash
# Set custom backend port (default is 5101)
BACKEND_PORT=8000

# Other configurations
FLASK_ENV=development
CORS_ORIGINS=http://localhost:3031
```

### Method 2: Docker Compose Override
```bash
# Custom compose file with different ports
BACKEND_PORT=8080 docker-compose up
```

### Method 3: Direct Environment on Host (Linux/Mac)
```bash
export BACKEND_PORT=8000
python backend/app.py
```

---

## 📋 Default Settings Summary

| Service | Type | Default Value | Can Override | Method |
|---------|------|---------------|--------------|--------|
| Backend Host Port | Docker | 5101 | ✅ | `BACKEND_PORT` env var |
| Backend Container Port | Docker | 5000 | ❌ | N/A |
| Backend Listen Address | App | 0.0.0.0 | ❌ | N/A |
| Frontend Host Port | Docker | 3031 | ❌ | N/A |
| Frontend Container Port (Dev) | Vite | 3031 | ❌ | N/A |
| Frontend Container Port (Prod) | Nginx | 80 | ❌ | N/A |
| API Proxy Backend | Vite | localhost:5101 | ✅ | `BACKEND_PORT` env var |
| CORS Origins | Flask | http://localhost:3031 | ✅ | `CORS_ORIGINS` env var |
| Database Health Check | Docker | Port 5000 | ❌ | N/A |

---

## 🚀 Common Customization Scenarios

### Scenario 1: Change Backend Port to 8000
```bash
# In .env file
BACKEND_PORT=8000

# Or via command line
docker-compose up -e BACKEND_PORT=8000
```

### Scenario 2: Change Frontend Port to 3032
**Currently not configurable** - Would require modifications to:
- `frontend/vite.config.ts` (line 52: change `port: 3031` to `port: 3032`)
- `docker-compose.yml` (line 48: change `3031:80` to `3032:80`)
- `backend/config.py` (line 105: update `CORS_ORIGINS` to include `http://localhost:3032`)

### Scenario 3: Deploy on Different Host Address
The application is configured to listen on `0.0.0.0` (all interfaces), so it will be accessible from any host IP. No code changes needed.

### Scenario 4: Production Deployment on Cloud
- Remove port mappings to only expose via load balancer/reverse proxy
- Use environment variables for `BACKEND_PORT`, `CORS_ORIGINS`, API endpoints
- Configure proper SSL/TLS on reverse proxy

---

## 🔐 Security Considerations

| Configuration | Security Level | Notes |
|---------------|-----------------|-------|
| Backend Port (5000) | Internal only | Should not be exposed directly to internet |
| Frontend Port (3000) | Development only | Use reverse proxy in production |
| CORS Origins | Configurable | Set to specific domain in production |
| Health Check Endpoint | Public | No authentication - consider adding in production |

---

## 📝 Files Requiring Changes for Port Customization

### To Change Backend Port (Host):
- ✏️ `.env` file (add `BACKEND_PORT=xxxx`)
- 📍 No code changes needed

### To Change Frontend Port (Host) from Current 3031:
- ✏️ [frontend/vite.config.ts](frontend/vite.config.ts#L52)
- ✏️ [docker-compose.yml](docker-compose.yml#L48)
- ✏️ [docker-compose.prod.yml](docker-compose.prod.yml#L34)
- ✏️ [backend/config.py](backend/config.py#L105) - CORS configuration

### To Change Backend Container Port:
- ✏️ [backend/app.py](backend/app.py#L267) - Change port parameter
- ✏️ [docker-compose.yml](docker-compose.yml#L14) - Update mapping
- ✏️ [docker-compose.prod.yml](docker-compose.prod.yml#L14) - Update mapping
- ✏️ [backend/Dockerfile](backend/Dockerfile) - Add EXPOSE statement

---

## 📚 Reference Documentation

### Docker Compose Port Syntax
```yaml
ports:
  - "host_port:container_port"
```

### Flask Port Configuration
```python
app.run(host='0.0.0.0', port=port, debug=debug)
```

### Vite Dev Server Configuration
```typescript
server: {
  port: 3000,
  host: true
}
```

### Nginx Port (Dockerfile)
```dockerfile
EXPOSE 80
```

---

## ✅ Verification Steps

To verify current port configuration:

1. **Check Backend Port:**
   ```bash
   curl http://localhost:5101/health
   ```

2. **Check Frontend:**
   ```bash
   curl http://localhost:3031
   ```

3. **Check Environment Variables:**
   ```bash
   echo $BACKEND_PORT
   ```

4. **View Docker Port Mappings:**
   ```bash
   docker-compose ps
   ```

---

## 📌 Summary Table

| Layer | Frontend | Backend |
|-------|----------|---------|
| **Host Machine** | localhost:3031 | localhost:$BACKEND_PORT (default: 5101) |
| **Docker Network** | banana-slides-frontend:80 | banana-slides-backend:5000 |
| **Service Type** | Nginx (Prod) / Vite (Dev) | Flask API |
| **Health Check** | GET / | GET /health |
| **Configurable** | No | Yes (BACKEND_PORT) |
| **Typical Use Cases** | Web UI | API Endpoints |

---

**End of Report**

For additional customization needs or port-related issues, refer to the specific file locations mentioned throughout this report.

---

## 📋 AI Provider Configuration Summary

### Default Setup (Cloud)
```env
AI_PROVIDER_FORMAT=gemini
GOOGLE_API_KEY=your-api-key-here
TEXT_MODEL=gemini-3-flash-preview
IMAGE_MODEL=gemini-3-pro-image-preview
```

### Local Ollama Setup
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_BASE=http://host.docker.internal:11434/v1
OPENAI_API_KEY=ollama
OLLAMA_TEXT_MODEL=llama2
OLLAMA_IMAGE_MODEL=llava
VISION_MODEL_ENDPOINT=http://host.docker.internal:11434
```

### Local LM Studio Setup
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_BASE=http://127.0.0.1:14321/api/v1
OPENAI_API_KEY=your-token-if-required
LM_STUDIO_TEXT_MODEL=ibm/granite-4-micro
```

### Alternative: OpenAI Cloud
```env
AI_PROVIDER_FORMAT=openai
OPENAI_API_KEY=sk-...
OPENAI_API_BASE=https://api.openai.com/v1
```

---

## ✅ Pre-Deployment Validation

Before running containers, use the pre-flight validation script to check your environment:

```powershell
cd c:\container\banana-slides
powershell -ExecutionPolicy Bypass -File scripts/pre-flight-check.ps1
```

### What the Script Checks:

| Check | Purpose | Status |
|-------|---------|--------|
| **Docker Installation** | Verifies Docker is installed and running | ✓ |
| **Port Availability** | Checks ports 5101, 3031, 11434, 14321 | ✓ |
| **Configuration Files** | Validates docker-compose.yml and .env.example | ✓ |
| **Environment File** | Confirms .env exists (optional) | ⚠️ |
| **Local Services** | Tests Ollama and LM Studio connectivity | ⚠️ |

### Expected Output:
```
馃崒 Banana Slides Pre-Flight Check

1. Docker Check
   [+] Docker: Docker version 29.1.5, build 0e6fee6

2. Port Availability
   [+] Port 5101: Available
   [+] Port 3031: Available
   [+] Port 11434: In use
   [+] Port 14321: Available

3. Configuration Files
   [+] docker-compose.yml found
   [+] .env.example found

4. Environment Configuration
   [!] .env file not found (create from .env.example)

5. Local Services
   [!] Ollama not responding (optional)
   [!] LM Studio not responding (optional)

Results:
  [+] Passed:   7
  [!] Warnings: 3
  [-] Failed:   0

[SUCCESS] Ready to deploy!
  Run: docker-compose up -d
```

### Setup Steps:

1. **Create .env file:**
   ```powershell
   Copy-Item .env.example .env
   ```

2. **Configure API Keys (if using cloud providers):**
   - For Gemini: Set `GOOGLE_API_KEY` in .env
   - For OpenAI: Set `OPENAI_API_KEY` in .env

3. **Run pre-flight check:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/pre-flight-check.ps1
   ```

4. **Deploy containers:**
   ```powershell
   docker-compose up -d
   ```

5. **Monitor startup:**
   ```powershell
   docker-compose logs -f
   ```

---

## 🚀 Quick Start Commands

**Start with Cloud Gemini (Default):**
```bash
docker-compose up
# Access: http://localhost:3031
```

**Start with Local Ollama:**
```bash
# Terminal 1: Start Ollama
docker run -d -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
ollama pull llama2 && ollama pull llava

# Terminal 2: Update .env and run
echo "OPENAI_API_BASE=http://host.docker.internal:11434/v1" >> .env
echo "OPENAI_API_KEY=ollama" >> .env
docker-compose up
```

**Start with Local LM Studio:**
```bash
# 1. Download LM Studio from https://lmstudio.ai/
# 2. Run it locally and load a model
# 3. Update .env
echo "OPENAI_API_BASE=http://127.0.0.1:14321/api/v1" >> .env
# 4. Run containers
docker-compose up
```

---

**Last Updated:** February 2, 2026  
**Current Port Configuration:**
- Backend: `5101:5000`
- Frontend: `3031:80`
- Ollama (if local): `host.docker.internal:11434`
- LM Studio (if local): `127.0.0.1:14321`

---

## 🧪 E2E Testing Configuration (Playwright) - UPDATED Feb 3, 2026

### Recent Updates

The E2E testing infrastructure has been updated to support dynamic port configuration for testing against the application running on port 3031 instead of the default 3000.

#### Modified Files:

**1. [frontend/playwright.config.ts](frontend/playwright.config.ts)**
- Added environment variable support for base URL configuration
- Supports `PLAYWRIGHT_BASE_URL` env var (defaults to `http://localhost:3000`)
- Added `PLAYWRIGHT_WEB_SERVER_DISABLED` flag to use existing running containers

**2. [frontend/e2e/ui-full-flow.spec.ts](frontend/e2e/ui-full-flow.spec.ts)**
- Added dynamic base URL helper function with `buildUrl()`
- Replaced all hardcoded `http://localhost:3000` references

**3. [frontend/e2e/ui-full-flow-mocked.spec.ts](frontend/e2e/ui-full-flow-mocked.spec.ts)**
- Updated to use environment variable for base URL
- Replaced hardcoded localhost:3000 with dynamic configuration

**4. [frontend/e2e/visual-regression.spec.ts](frontend/e2e/visual-regression.spec.ts)**
- Added `buildUrl()` helper function
- Updated 5 hardcoded URL instances to use configurable base URL

#### Running E2E Tests Against Port 3031:

```powershell
# Set environment variables
$env:PLAYWRIGHT_BASE_URL="http://localhost:3031"
$env:PLAYWRIGHT_WEB_SERVER_DISABLED="true"

# Run all tests
npx playwright test --reporter=list --workers=1
```

#### Test Coverage:

| Test File | Purpose | Status |
|-----------|---------|--------|
| ui-full-flow.spec.ts | Full end-to-end workflow | ✅ Passing |
| visual-regression.spec.ts | Visual regression checks | ✅ All 5 tests passing |

#### Browser Support:

- Chromium: 143.0.7499.4
- Firefox: Available
- WebKit: Available
