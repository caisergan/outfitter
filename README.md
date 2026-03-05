# Outfitter

Outfitter is a personal fashion and wardrobe management application with an AI-powered try-on feature, semantic wardrobe search, and outfit suggestions.

## Project Structure

```text
outfitter/
├── backend/   # FastAPI API server with PostgreSQL (pgvector) and Redis
├── admin/     # Next.js admin panel for managing the backend
└── docs/      # Project documentation
```

## Backend

### Prerequisites

- Python 3.12+
- Docker and Docker Compose (recommended)
- PostgreSQL with pgvector extension
- Redis

### Running with Docker (Recommended)

1. Navigate to the backend directory:

   ```bash
   cd backend
   ```

2. Create a `.env` file from the example:

   ```bash
   cp .env.example .env
   ```

3. Start all services (API, PostgreSQL, Redis):

   ```bash
   docker-compose up --build
   ```

The API will be available at `http://localhost:8000`.

### Running Manually

1. Navigate to the backend directory and create a virtual environment:

   ```bash
   cd backend
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

2. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

3. Configure environment variables in a `.env` file.

4. Run database migrations:

   ```bash
   alembic upgrade head
   ```

5. Start the server:

   ```bash
   uvicorn app.main:app --reload
   ```

### API Documentation

With the server running, interactive docs are available at:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

---

## Admin Panel

A Next.js admin interface for browsing and managing all backend resources — catalog items, wardrobe, outfits, and try-on jobs.

### Requirements

- Node.js 18+
- npm (bundled with Node.js)
- A running backend instance (see above)

### Setup

1. Navigate to the admin directory:

   ```bash
   cd admin
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Create a local environment file:

   ```bash
   cp .env.local.example .env.local   # or create .env.local manually
   ```

   Set the backend URL (defaults to `http://localhost:8000` if not set):

   ```env
   NEXT_PUBLIC_API_URL=http://localhost:8000
   ```

4. Start the development server:

   ```bash
   npm run dev
   ```

The admin panel will be available at `http://localhost:3000`.

### Building for Production

```bash
npm run build
npm start
```

### Pages

| Route | Description |
| ------- | ----------- |
| `/login` | JWT authentication |
| `/` | Dashboard overview |
| `/catalog` | Browse and search catalog items |
| `/wardrobe` | Manage user wardrobe items |
| `/outfits` | View and manage saved outfits |
| `/tryon` | Manage AI try-on jobs |

---

## Development Workflow

This project follows [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat:     New feature
fix:      Bug fix
refactor: Code change that neither fixes a bug nor adds a feature
chore:    Tooling, dependencies, configuration
test:     Adding or updating tests
docs:     Documentation changes
```
