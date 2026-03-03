# Outfitter

Outfitter is a personal fashion and wardrobe management application.

## Project Structure

- `backend/`: FastAPI application with PostgreSQL (pgvector) and Redis.
- `docs/`: Project documentation and tasks.

## Getting Started

### Prerequisites

- Python 3.11+
- Docker and Docker Compose (recommended)
- PostgreSQL (if running manually)
- Redis (if running manually)

### Running with Docker (Recommended)

The easiest way to get started is using Docker Compose, which sets up the API, PostgreSQL (with pgvector), and Redis.

1. Navigate to the backend directory:

   ```bash
   cd backend
   ```

2. Create a `.env` file from the example:

   ```bash
   cp .env.example .env
   ```

3. Start the services:

   ```bash
   docker-compose up --build
   ```

The API will be available at `http://localhost:8000`.

### Running Manually

If you prefer to run the backend manually:

1. Navigate to the backend directory:

   ```bash
   cd backend
   ```

2. Create and activate a virtual environment:

   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

3. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

4. Set up your environment variables in a `.env` file.

5. Run database migrations:

   ```bash
   alembic upgrade head
   ```

6. Start the FastAPI server:

   ```bash
   uvicorn app.main:app --reload
   ```

## API Documentation

Once the server is running, you can access the interactive API documentation at:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Development Workflow

### Committing Changes

This project uses a chunked commit workflow. When adding new features:

1. Stage your changes: `git add .`
2. Commit with a descriptive message: `git commit -m "Feature: Description"`
3. Push to GitHub: `git push origin main`
