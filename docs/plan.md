# TowerTrace Plan

## Phase 1: Foundation

Status: **approved 2026-10-05, blocked on shell access** (no steps started)

### Goal

`docker compose up` gives a running app. An analyst can create a case and upload a file, which is stored in MinIO with its SHA256 recorded. `bin/rails towertrace:generate[42]` produces every carrier format deterministically. GitHub Actions runs the suite and it passes.

### Steps (one focused commit each, tests included)

1. **Repo and app skeleton**
   - `git init`, then `rails new . --database=postgresql --javascript=importmap --skip-jbuilder` (Rails 8, Ruby 3.3+). This gives Solid Queue, Propshaft, Hotwire and RuboCop by default.
   - Add `.env.example`, `.gitignore` entries (`sample_data/` output, `.env`, `storage/`), `docs/decisions.md`, `README.md` skeleton.
   - Commit only after `bin/rails test` and `bin/rubocop` pass on the empty app.

2. **Docker Compose stack**
   - Services: `app` (Rails dev server), `postgres` (`pgvector/pgvector:pg16`, so the extension is there from day one), `minio` plus a one-shot `minio-init` that creates the bucket.
   - Development `Dockerfile` (`Dockerfile.dev`) next to the Rails 8 production `Dockerfile`.
   - Database settings come from `DATABASE_URL`, MinIO from `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_BUCKET` (all listed in `.env.example`).
   - Active Storage: `minio` service in `config/storage.yml` (S3 with `force_path_style: true`) for development and Compose; `test` uses the local Disk service so tests need no MinIO.
   - `bin/setup` works from a clean clone: bundle install, copy `.env.example` to `.env` if missing, `db:prepare`.

3. **Cases CRUD**
   - `Case` model (name required, description), scaffold-style controller and views with Turbo, no extra gems.
   - Model tests, controller/integration tests, fixtures.

4. **Evidence upload**
   - `EvidenceFile` (belongs to Case): `has_one_attached :original`, `original_filename`, `sha256`, `detected_format` (nil until Phase 2), `status` enum (pending, importing, imported, failed), `uploaded_at`.
   - SHA256 is computed by streaming the uploaded IO before attaching, then cross-checked against the stored blob. The blob is never rewritten. A model validation stops anything from changing `sha256` after create.
   - Tests: the hash matches a known fixture file's digest, the original bytes come back byte for byte, and an edit to `sha256` is rejected.
   - Only `Case` and `EvidenceFile` tables in this phase. `ImportRun`, `ImportError`, `Tower`, `Phone`, `Event` land in Phase 2, where their tests are.

5. **Synthetic data generator** (`lib/towertrace/generator/*`, `lib/tasks/towertrace.rake`)
   - All randomness goes through one `Random.new(seed)`. There are no `Time.now`, `Hash` ordering surprises or `SecureRandom`. The start date is fixed (2025-03-03, America/Phoenix, chosen because it has no DST).
   - Towers: read `sample_data/opencellid/*.csv` filtered to a Phoenix bounding box. If no file is present, generate seeded points in the box. Three sectors per site (0/120/240°, 120° beam).
   - People: 30 from a fixed fake-name list, with home/work towers, a routine and 1 to 2 phones. Numbers are `+1 XXX 555 01XX` with seeded fictional area codes. That allows only 100 unique numbers per area code, so the generator uses a few area codes and asserts uniqueness.
   - Events: three weeks of calls and SMS, weighted toward 3 to 5 close contacts each, served by the tower nearest to the caller's scheduled location.
   - Planted patterns plus `sample_data/ground_truth.json`: co-location pair, 3-day burner, cross-town trip day.
   - Exports: Alpha CSV, Bravo XLSX plus tower list (caxlsx), Charlie PDF (prawn and prawn_table).
   - Broken variants: Alpha v2 with a renamed column, blank and duplicated rows, Bravo with mixed 12/24h times, a PDF with one unreadable page, and an unknown format.
   - Tests: the same seed gives byte-identical CSV and JSON plus identical parsed XLSX/PDF content, a different seed gives different output, all numbers fall in the 555-01XX range, and the ground-truth patterns can be found in the generated events.

6. **CI**
   - `.github/workflows/ci.yml`: Postgres (pgvector image) service, `bin/rubocop`, `bin/rails test`. A README badge.
   - The Jenkinsfile waits for Phase 6, as the brief says.

7. **Docs**: README (setup, generate, tests, Mermaid diagram) and the first entries in `docs/decisions.md`.

### Dependencies used this phase (all in the stack table)

`pg`, `aws-sdk-s3` (Active Storage S3 adapter), `caxlsx`, `prawn`, `prawn-table`. Phase 1 also adds `roo` and `pdf-reader`, test-only, to read the generated XLSX and PDF back in the generator tests. Both are already in the stack table.

### Open questions (data model / interface)

1. **`detected_format` and `status` storage.** I plan to store both as strings with Rails `enum` on `status`. Integers are the other option. Strings read better in raw SQL and exports, so I'll use strings unless you object.
2. **OpenCelliD file.** If you have one, place it in `sample_data/opencellid/` before step 5. Otherwise the seeded fallback is used, and tests always use the fallback so CI never depends on that file.

### Toolchain check (pending)

The shell was unavailable when this plan was written, so I haven't yet confirmed that Ruby 3.3+, Rails 8, Docker, Node and PostgreSQL client tools are installed. That check is the first thing I'll do after go-ahead.
