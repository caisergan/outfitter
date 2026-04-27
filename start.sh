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
# Step 1: Check Prerequisites
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker is running${NC}"

# Check Node.js
if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}❌ Node.js is not installed. Admin dashboard requires Node.js.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Node.js is installed${NC}"

# Check .env files
if [ ! -f "backend/.env" ]; then
    echo -e "${RED}❌ backend/.env not found. Please create it from backend/.env.example.${NC}"
    exit 1
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

cd backend
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

echo -e "${YELLOW}Waiting for Backend API to be healthy...${NC}"
# Wait for the API docs page to be accessible
while ! curl -s http://localhost:8000/docs >/dev/null; do
    sleep 1
done
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