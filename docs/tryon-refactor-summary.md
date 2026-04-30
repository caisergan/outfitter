# Try-On Refactor Summary

Date: 2026-04-30

## Objective

Rename the former playground generation surface to try-on across the backend, database, admin app, mobile app, and project documentation. The refactor keeps the existing legacy try-on job endpoints while moving the generation studio endpoints under the same `/tryon` API namespace.

## Graphify Exploration

The existing `graphify-out/graph.json` was used before editing to locate backend routers, SQLAlchemy models, Alembic migrations, admin pages/API helpers, mobile routes, Riverpod providers, repositories, and tests tied to the old naming.

After the refactor, `graphify update .` rebuilt the graph:

- Nodes: 1481
- Edges: 2427
- Communities: 90
- Updated outputs: `graphify-out/graph.json`, `graphify-out/graph.html`, `graphify-out/GRAPH_REPORT.md`

## Backend Changes

- Replaced the generation router module with `backend/app/routers/tryon_generation.py`.
- Registered the generation router as `tryon_generation_router` in `backend/app/routers/__init__.py`.
- Mounted generation endpoints under `/tryon` in `backend/app/main.py`.
- Preserved the existing legacy router in `backend/app/routers/tryon.py`, including:
  - `POST /tryon/submit`
  - `GET /tryon/status/{job_id}`
- Renamed generation schemas to `backend/app/schemas/tryon_generation.py`.
- Renamed the generation model module to `backend/app/models/tryon_generation.py`.
- Renamed `PlaygroundRun` to `TryOnRun`.
- Renamed storage keys from the old prefix to `tryon/{user_id}/{run_id}/{index}.png`.
- Renamed generation settings:
  - `PLAYGROUND_DAILY_CAP` -> `TRYON_DAILY_CAP`
  - `PLAYGROUND_FAILED_RUNS_COUNT_TOWARD_CAP` -> `TRYON_FAILED_RUNS_COUNT_TOWARD_CAP`
- Renamed saved outfit source values from the old source to `tryon`.

Current generation endpoint surface:

- `GET /tryon/system-prompt`
- `GET /tryon/templates`
- `GET /tryon/personas`
- `POST /tryon/generate-image`
- `GET /tryon/runs`
- `GET /tryon/runs/{run_id}`
- Admin CRUD endpoints under the same `/tryon` router remain protected by admin auth.

## Database Changes

Fresh migrations now create the generation run table as `tryon_runs`.

Renamed database objects:

- Table: `playground_runs` -> `tryon_runs`
- Check constraint: `ck_playground_runs_status` -> `ck_tryon_runs_status`
- Index: `ix_playground_runs_user_id_created_at` -> `ix_tryon_runs_user_id_created_at`
- Saved outfit source value: `playground` -> `tryon`

Migration files:

- `backend/alembic/versions/0008_tryon_generation_tables_and_seeds.py`
- `backend/alembic/versions/0010_tryon_runs_pending_status.py`
- `backend/alembic/versions/0011_rename_playground_objects_to_tryon.py`

`0011_rename_playground_objects_to_tryon.py` intentionally contains the old object names because it must detect and rename existing deployed database objects during upgrade and restore them during downgrade.

## Admin App Changes

- Moved the former generation studio UI to `admin/src/app/tryon/page.js`.
- Moved the older try-on job diagnostic page to `admin/src/app/tryon/jobs/page.js`.
- Removed the active `/playground` admin route.
- Updated sidebar navigation:
  - `/tryon` -> Try-On Studio
  - `/tryon/jobs` -> Try-On Jobs
- Renamed admin API helpers in `admin/src/lib/api.js` from playground-style names to try-on names.
- Updated admin system prompt, template, persona, outfit source, and copy surfaces to use try-on naming.

## Mobile App Changes

- Moved the feature directory:
  - `mobile/lib/features/playground` -> `mobile/lib/features/tryon`
- Moved generated API models:
  - `mobile/lib/core/models/playground_models.dart` -> `mobile/lib/core/models/tryon_models.dart`
- Regenerated:
  - `mobile/lib/core/models/tryon_models.freezed.dart`
  - `mobile/lib/core/models/tryon_models.g.dart`
- Renamed main UI and support files:
  - `playground_screen.dart` -> `tryon_screen.dart`
  - `playground_stack_panel.dart` -> `tryon_stack_panel.dart`
  - `playground_repository.dart` -> `tryon_generation_repository.dart`
  - `playground_draft_provider.dart` -> `tryon_draft_provider.dart`
  - `playground_library_provider.dart` -> `tryon_library_provider.dart`
  - `playground_runs_provider.dart` -> `tryon_runs_provider.dart`
- Updated route path:
  - `/playground` -> `/tryon`
- Updated call sites in assistant, discover, profile, wardrobe, shared widgets, router, and tests.
- Moved tests:
  - `mobile/test/features/playground` -> `mobile/test/features/tryon`

The legacy mobile try-on submission repository was preserved as `mobile/lib/features/tryon/data/tryon_repository.dart`; the gpt-image-2 generation client now lives separately in `tryon_generation_repository.dart`.

## Verification

Backend:

- `.venv/bin/python -m pytest tests/test_tryon_generation.py -v`
  - 41 passed
- `.venv/bin/python -m pytest -q`
  - 98 passed in 14.41s

Mobile:

- `dart run build_runner build --delete-conflicting-outputs`
  - Succeeded, 414 outputs
  - Non-blocking analyzer SDK language-version warning emitted by build_runner
- `flutter analyze`
  - No issues found in 2.1s
- `flutter test`
  - 3 tests passed

Admin:

- `npm run build`
  - Build succeeded
  - Generated routes include `/tryon` and `/tryon/jobs`
  - Next.js emitted an existing workspace-root warning because multiple lockfiles are present

Graph:

- `graphify update .`
  - Rebuilt successfully

## Audit Notes

- Active backend, admin, mobile, and docs source paths no longer expose `/playground` routes.
- The old term intentionally remains in compatibility migration `0011_rename_playground_objects_to_tryon.py` and refactor planning artifacts so existing databases can be upgraded safely.
- Existing unrelated dirty files were present in the worktree and were not treated as part of this refactor.
