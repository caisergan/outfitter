#!/bin/bash

# =============================================================================
# Outfitter - Project Startup Script
# =============================================================================
# This script starts all services for the Outfitter project 
# Compatible with: Linux, macOS, WSL, Git Bash / MSYS2
# =============================================================================

set -e

# Get the absolute path to the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

get_env_value() {
    local key="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        return 0
    fi

    awk -F= -v target="$key" '
        $1 == target {
            value = substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
        }
    ' "$file" | tail -n 1
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Detect Environment
# -----------------------------------------------------------------------------
detect_env() {
    if grep -qEi "microsoft|wsl" /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || -n "$MSYSTEM" ]]; then
        echo "gitbash"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

ENV_TYPE=$(detect_env)

# -----------------------------------------------------------------------------
# Cross-platform: Kill process on port
# -----------------------------------------------------------------------------
kill_port() {
    local port="$1"
    if [[ "$ENV_TYPE" == "gitbash" || "$ENV_TYPE" == "msys" ]]; then
        # Git Bash / MSYS2: PowerShell üzerinden
        local pids
        pids=$(powershell.exe -NoProfile -Command \
            "Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess" \
            2>/dev/null | tr -d '\r')
        if [ -n "$pids" ]; then
            for pid in $pids; do
                [ "$pid" -gt 0 ] 2>/dev/null && \
                    powershell.exe -NoProfile -Command "Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
            done
        fi
    else
        # Linux / macOS / WSL: lsof
        if command -v lsof >/dev/null 2>&1; then
            kill "$(lsof -ti:"$port")" 2>/dev/null || true
        elif command -v fuser >/dev/null 2>&1; then
            fuser -k "${port}/tcp" 2>/dev/null || true
        fi
    fi
}

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                           ║"
echo "║                     🚀 Outfitter Startup Script 🚀                       ║"
echo "║                                                                           ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${BLUE}  Detected environment: ${GREEN}${ENV_TYPE}${NC}"
echo ""

# -----------------------------------------------------------------------------
# Handle 'stop' Command
# -----------------------------------------------------------------------------
if [ "$1" == "stop" ]; then
    echo -e "${YELLOW}Stopping all services...${NC}"
    if [ -d "backend" ]; then
        echo -e "${BLUE}  Stopping Backend (Docker)...${NC}"
        cd backend && docker compose down 2>/dev/null || true
        cd "$SCRIPT_DIR"
    fi
    echo -e "${BLUE}  Killing existing Admin processes (Port 3000)...${NC}"
    kill_port 3000
    echo -e "${GREEN}✓ All services stopped.${NC}"
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 1: Check & Auto-Install Prerequisites
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

# --- Helper: pick a package manager available on this system ----------------
detect_pkg_manager() {
    if [[ "$ENV_TYPE" == "macos" ]]; then
        command -v brew >/dev/null 2>&1 && { echo "brew"; return; }
    elif [[ "$ENV_TYPE" == "linux" || "$ENV_TYPE" == "wsl" ]]; then
        command -v apt-get >/dev/null 2>&1 && { echo "apt"; return; }
        command -v dnf     >/dev/null 2>&1 && { echo "dnf"; return; }
        command -v pacman  >/dev/null 2>&1 && { echo "pacman"; return; }
    elif [[ "$ENV_TYPE" == "gitbash" ]]; then
        command -v winget.exe >/dev/null 2>&1 && { echo "winget"; return; }
        command -v choco.exe  >/dev/null 2>&1 && { echo "choco"; return; }
    fi
    echo "none"
}

PKG_MANAGER=$(detect_pkg_manager)

install_pkg() {
    # install_pkg <human_name> <brew_name> <apt_name> <dnf_name> <pacman_name> <winget_id> <choco_id>
    local human="$1" brew_pkg="$2" apt_pkg="$3" dnf_pkg="$4" pacman_pkg="$5" winget_id="$6" choco_id="$7"
    echo -e "${BLUE}  Installing ${human} via ${PKG_MANAGER}...${NC}"
    case "$PKG_MANAGER" in
        brew)   brew install "$brew_pkg" ;;
        apt)    sudo apt-get update -y && sudo apt-get install -y "$apt_pkg" ;;
        dnf)    sudo dnf install -y "$dnf_pkg" ;;
        pacman) sudo pacman -S --noconfirm "$pacman_pkg" ;;
        winget) winget.exe install --silent --accept-package-agreements --accept-source-agreements --id "$winget_id" ;;
        choco)  choco.exe install -y "$choco_id" ;;
        *)
            echo -e "${RED}❌ No supported package manager detected. Please install ${human} manually.${NC}"
            return 1
            ;;
    esac
}

# --- Docker ------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ Docker not installed. Attempting auto-install...${NC}"
    if [[ "$ENV_TYPE" == "macos" && "$PKG_MANAGER" == "brew" ]]; then
        brew install --cask docker
    elif [[ "$ENV_TYPE" == "linux" || "$ENV_TYPE" == "wsl" ]]; then
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker "$USER" 2>/dev/null || true
        else
            install_pkg "Docker" "" "docker.io" "docker" "docker" "Docker.DockerDesktop" "docker-desktop"
        fi
    elif [[ "$ENV_TYPE" == "gitbash" ]]; then
        install_pkg "Docker Desktop" "" "" "" "" "Docker.DockerDesktop" "docker-desktop"
    else
        echo -e "${RED}❌ Don't know how to install Docker on this platform. Install it manually: https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ Docker is installed but not running. Attempting to start it...${NC}"
    if [[ "$ENV_TYPE" == "macos" ]]; then
        open -a Docker 2>/dev/null || true
    elif [[ "$ENV_TYPE" == "linux" || "$ENV_TYPE" == "wsl" ]]; then
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
    elif [[ "$ENV_TYPE" == "gitbash" ]]; then
        powershell.exe -NoProfile -Command "Start-Process 'Docker Desktop'" 2>/dev/null || true
    fi

    echo -e "${BLUE}  Waiting up to 90s for Docker daemon...${NC}"
    DOCKER_WAIT=0
    until docker info >/dev/null 2>&1; do
        if [ "$DOCKER_WAIT" -ge 90 ]; then
            echo -e "${RED}❌ Docker daemon did not become available within 90s. Please start Docker manually and re-run.${NC}"
            exit 1
        fi
        sleep 2
        DOCKER_WAIT=$((DOCKER_WAIT + 2))
    done
fi
echo -e "${GREEN}  ✓ Docker is running${NC}"

# --- Node.js -----------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ Node.js not installed. Attempting auto-install...${NC}"
    install_pkg "Node.js" "node" "nodejs" "nodejs" "nodejs" "OpenJS.NodeJS.LTS" "nodejs-lts" || exit 1
fi
echo -e "${GREEN}  ✓ Node.js is installed ($(node --version 2>/dev/null))${NC}"

# --- npm (usually shipped with node, but verify) ----------------------------
if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}❌ npm not found even though Node.js is installed. Reinstall Node.js.${NC}"
    exit 1
fi

# --- curl (used later for the API health probe) -----------------------------
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ curl not installed. Attempting auto-install...${NC}"
    install_pkg "curl" "curl" "curl" "curl" "curl" "cURL.cURL" "curl" || exit 1
fi

# --- .env files --------------------------------------------------------------
if [ ! -f "backend/.env" ]; then
    if [ -f "backend/.env.example" ]; then
        echo -e "${YELLOW}  ⚠ backend/.env not found. Copying from backend/.env.example...${NC}"
        cp backend/.env.example backend/.env
        echo -e "${YELLOW}  ⚠ Review backend/.env and fill in real secrets before relying on this for anything beyond local dev.${NC}"
    else
        echo -e "${RED}❌ backend/.env and backend/.env.example are both missing. Cannot bootstrap backend config.${NC}"
        exit 1
    fi
fi
if [ ! -f "admin/.env.local" ]; then
    echo -e "${YELLOW}  ⚠ admin/.env.local not found. Creating default local URLs...${NC}"
    echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > admin/.env.local
fi
echo -e "${GREEN}  ✓ Environment files exist${NC}"

USE_EXTERNAL_DB="$(get_env_value "USE_EXTERNAL_DB" "backend/.env")"
if [ -z "$USE_EXTERNAL_DB" ]; then
    USE_EXTERNAL_DB="false"
fi

if [ "$USE_EXTERNAL_DB" == "true" ]; then
    echo -e "${GREEN}  ✓ Backend database mode: external${NC}"
else
    echo -e "${GREEN}  ✓ Backend database mode: bundled local Postgres${NC}"
fi

# -----------------------------------------------------------------------------
# Step 2: Clean up Existing Instances
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/5] Cleaning up existing instances...${NC}"

# Stop backend docker if running
if [ -d "backend" ]; then
    cd backend && docker compose down 2>/dev/null || true
    cd "$SCRIPT_DIR"
fi

# Kill any processes holding standard ports
echo -e "${BLUE}  Clearing port 3000 (Admin) and 8000 (API)...${NC}"
kill_port 3000
kill_port 8000
sleep 1

echo -e "${GREEN}  ✓ Cleanup complete${NC}"

# -----------------------------------------------------------------------------
# Step 3: Start Backend Services (Docker)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/5] Starting Backend (Docker)...${NC}"

# --- Auto-rebuild API image if Python deps / Dockerfile changed -------------
# We hash requirements.txt + Dockerfile and compare against the last successful
# build. If anything changed, rebuild before `up` so newly-added deps (e.g.
# torch via open-clip-torch) actually land in the image.
BUILD_HASH_FILE="$SCRIPT_DIR/.start.sh.api-build-hash"

compute_api_build_hash() {
    # Concatenate the files that, if changed, require a rebuild, and hash them.
    local hasher=""
    if command -v shasum >/dev/null 2>&1; then
        hasher="shasum -a 256"
    elif command -v sha256sum >/dev/null 2>&1; then
        hasher="sha256sum"
    else
        # Fallback: combined mtime. Worse, but never returns empty.
        stat -f '%m' "$SCRIPT_DIR/backend/requirements.txt" "$SCRIPT_DIR/backend/Dockerfile" 2>/dev/null \
            || stat -c '%Y' "$SCRIPT_DIR/backend/requirements.txt" "$SCRIPT_DIR/backend/Dockerfile" 2>/dev/null
        return
    fi
    cat "$SCRIPT_DIR/backend/requirements.txt" "$SCRIPT_DIR/backend/Dockerfile" 2>/dev/null \
        | $hasher | awk '{print $1}'
}

CURRENT_BUILD_HASH=$(compute_api_build_hash)
PREV_BUILD_HASH=$(cat "$BUILD_HASH_FILE" 2>/dev/null || echo "")

API_NEEDS_REBUILD=0
if [ -z "$PREV_BUILD_HASH" ]; then
    # No hash recorded -> we don't know if the cached image matches the current
    # requirements.txt/Dockerfile. Rebuild to be safe; the persisted hash will
    # short-circuit subsequent runs.
    API_NEEDS_REBUILD=1
    echo -e "${YELLOW}  ⚠ No prior API build hash recorded. Rebuilding API image to guarantee deps match...${NC}"
elif [ "$CURRENT_BUILD_HASH" != "$PREV_BUILD_HASH" ]; then
    API_NEEDS_REBUILD=1
    echo -e "${YELLOW}  ⚠ backend/requirements.txt or backend/Dockerfile changed. Rebuilding API image...${NC}"
fi

cd backend
if [ "$API_NEEDS_REBUILD" == "1" ]; then
    docker compose build api
fi

if [ "$USE_EXTERNAL_DB" == "true" ]; then
    docker compose up -d redis api
else
    docker compose up -d db redis
    echo -e "${YELLOW}Waiting for local PostgreSQL to be healthy...${NC}"
    until docker compose exec -T db pg_isready -U user -d outfitter >/dev/null 2>&1; do
        sleep 1
    done
    docker compose up -d api
fi
cd "$SCRIPT_DIR"

echo -e "${GREEN}  ✓ Backend services started in background${NC}"

# -----------------------------------------------------------------------------
# Step 4: Prepare Admin Frontend
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/5] Preparing Admin Frontend...${NC}"

cd admin
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}  Installing node_modules...${NC}"
    npm install
fi
cd "$SCRIPT_DIR"

wait_for_api() {
    # Wait for /docs to respond, with a bounded timeout. Returns:
    #   0 -> healthy
    #   1 -> container crashed OR app process keeps failing to import
    #        (caller should inspect logs / consider rebuild)
    #   2 -> timed out while still "running" with no obvious crash
    local timeout="${1:-90}"
    local elapsed=0
    local last_progress_at=0
    while ! curl -s -o /dev/null http://localhost:8000/docs; do
        local state
        state=$(docker inspect -f '{{.State.Status}}' backend-api-1 2>/dev/null || echo "missing")
        if [ "$state" != "running" ]; then
            return 1
        fi

        # Uvicorn --reload keeps the container parent alive while the worker
        # subprocess keeps crashing on import. Detect that by scanning recent
        # logs for import-time fatal errors.
        if docker logs --tail 80 backend-api-1 2>&1 \
            | grep -qE "ModuleNotFoundError|ImportError|Process SpawnProcess.*Traceback"; then
            return 1
        fi

        # Every 10s, surface what's happening so the user isn't staring at a
        # silent cursor. CLIP weights (~605 MB) are downloaded on first import;
        # we report container network I/O so a heavy download is visible.
        if [ $((elapsed - last_progress_at)) -ge 10 ] && [ "$elapsed" -gt 0 ]; then
            local net_io
            net_io=$(docker stats --no-stream --format '{{.NetIO}}' backend-api-1 2>/dev/null | head -n 1)
            if [ -n "$net_io" ]; then
                echo -e "${BLUE}  ...still waiting (${elapsed}s elapsed, container NET I/O: ${net_io})${NC}"
            else
                echo -e "${BLUE}  ...still waiting (${elapsed}s elapsed)${NC}"
            fi
            last_progress_at=$elapsed
        fi

        if [ "$elapsed" -ge "$timeout" ]; then
            return 2
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 0
}

dump_api_logs() {
    echo -e "${YELLOW}--- Last 80 lines of backend-api-1 logs ---${NC}"
    docker logs --tail 80 backend-api-1 2>&1 || true
    echo -e "${YELLOW}-------------------------------------------${NC}"
}

echo -e "${YELLOW}Waiting for Backend API to be healthy (first run can take a few minutes if model weights need to download)...${NC}"
wait_for_api 300
API_HEALTH=$?

# If the container died, see if it's a missing-dep crash and auto-rebuild once.
if [ "$API_HEALTH" == "1" ]; then
    API_LOGS=$(docker logs --tail 200 backend-api-1 2>&1 || true)
    if echo "$API_LOGS" | grep -qE "ModuleNotFoundError|ImportError"; then
        MISSING_MOD=$(echo "$API_LOGS" | grep -oE "No module named '[^']+'" | tail -n 1)
        echo -e "${YELLOW}  ⚠ API crashed due to missing Python dependency (${MISSING_MOD:-unknown}).${NC}"
        echo -e "${YELLOW}  ⚠ Auto-rebuilding API image (this may take a few minutes for heavy deps like torch)...${NC}"
        (cd backend && docker compose build --no-cache api && docker compose up -d api)
        echo -e "${BLUE}  Re-checking API health after rebuild...${NC}"
        wait_for_api 300
        API_HEALTH=$?
    fi
fi

if [ "$API_HEALTH" != "0" ]; then
    if [ "$API_HEALTH" == "1" ]; then
        echo -e "${RED}❌ Backend API container exited.${NC}"
    else
        echo -e "${RED}❌ Backend API did not become healthy in time.${NC}"
    fi
    dump_api_logs
    echo -e "${RED}If this looks like a code bug, fix it and re-run ./start.sh.${NC}"
    echo -e "${RED}If you suspect a stale image, force a clean rebuild with:${NC}"
    echo -e "  ${BLUE}cd backend && docker compose build --no-cache api && docker compose up -d api${NC}"
    exit 1
fi

# Persist the build hash now that we know the image works.
[ -n "$CURRENT_BUILD_HASH" ] && echo "$CURRENT_BUILD_HASH" > "$BUILD_HASH_FILE"

echo -e "${GREEN}  ✓ Backend API is up!${NC}"

# -----------------------------------------------------------------------------
# Step 5: Dashboard & Foreground Start
# -----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                       🎉 Outfitter is Ready! 🎉${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Services Access:${NC}"
echo -e "  📊 Admin Dashboard:     ${GREEN}http://localhost:3000${NC}"
echo -e "  🔌 Backend API:        ${GREEN}http://localhost:8000${NC}"
echo ""
echo -e "${YELLOW}Backend Logs:${NC}"
echo -e "  View with:           ${BLUE}cd backend && docker compose logs -f api${NC}"
echo ""
echo -e "${BLUE}Starting Admin Frontend in foreground (Next.js logs)...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop BOTH Admin and Backend containers.${NC}"
echo ""

# Shutdown Handler
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down services...${NC}"
    cd "$SCRIPT_DIR/backend" && docker compose down 2>/dev/null || true
    echo -e "${GREEN}✓ Everything stopped.${NC}"
    exit 0
}

# Trap Ctrl+C (SIGINT) and SIGTERM
trap cleanup SIGINT SIGTERM

# Start Admin in foreground
cd "$SCRIPT_DIR/admin"
npm run dev