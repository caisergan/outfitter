# AWS PostgreSQL Setup

This project's backend depends on PostgreSQL-specific features:

- `pgvector` for `Vector(512)` embedding columns
- HNSW vector indexes for similarity search
- PostgreSQL array, JSONB, and UUID types

Use one of these AWS targets:

- Amazon RDS for PostgreSQL
- Amazon Aurora PostgreSQL

## Prerequisites

1. Create a PostgreSQL database in AWS.
2. Pick a version/engine that supports `pgvector >= 0.5.0`.
3. Allow the backend host to reach port `5432`.
4. Create the `outfitter` database and an application user.

## Backend Configuration

Use [`backend/.env.aws.example`](/Users/egeayyildiz/Desktop/personal-projects/outfitter/backend/.env.aws.example) as your starting point.

Key variables:

- `DATABASE_URL`: used by host-side commands like `alembic upgrade head`
- `DOCKER_DATABASE_URL`: used by the Docker `api` container
- `USE_EXTERNAL_DB=true`: tells [`start.sh`](/Users/egeayyildiz/Desktop/personal-projects/outfitter/start.sh) to skip the bundled local Postgres container

Example:

```env
DATABASE_URL=postgresql+asyncpg://aws_user:aws_password@your-db-endpoint.us-east-1.rds.amazonaws.com:5432/outfitter?ssl=require
DOCKER_DATABASE_URL=postgresql+asyncpg://aws_user:aws_password@your-db-endpoint.us-east-1.rds.amazonaws.com:5432/outfitter?ssl=require
USE_EXTERNAL_DB=true
```

## Migrations

Run schema setup before starting the API:

```bash
cd backend
alembic upgrade head
```

If you prefer to run migrations inside Docker:

```bash
cd backend
docker compose run --rm api alembic upgrade head
```

The initial migration creates the `vector` extension automatically. Your AWS PostgreSQL engine must allow `CREATE EXTENSION vector`.

## Running the Backend

From the repo root:

```bash
./start.sh
```

When `USE_EXTERNAL_DB=true`, the script starts:

- `redis`
- `api`

It does not start the local `db` container.

## Verification

1. Confirm the database is reachable from your machine or backend host.
2. Run `alembic upgrade head` successfully.
3. Start the backend and open `http://localhost:8000/docs`.
4. Test a route that reads or writes PostgreSQL data.
