# Decisions

One short entry per decision, newest at the bottom.

### 1. Ruby 3.4 via mise
The host had only macOS system Ruby 2.6. Ruby 3.4.11 is installed with mise and pinned in `.ruby-version` and `mise.toml`. Ruby 3.4 meets the "3.3+" requirement and is the current stable line.

### 2. MinIO image from pgsty/minio
MinIO stopped publishing official images in 2025 (`minio/minio` on Docker Hub and `quay.io/minio/minio` both refuse pulls). We use `pgsty/minio`, a community build of the same server maintained by the Pigsty project, pinned to an exact release tag. The tradeoff is depending on a third-party maintainer. Active Storage only speaks the S3 API, so swapping to another S3-compatible store later is a config change.

### 3. No Kamal, no Thruster
`rails new` was run with `--skip-kamal --skip-thruster`. Deployment is Kubernetes (Minikube) and Ansible per the brief, so Kamal would be a second, unused deploy path.

### 4. Dropped image_processing
Rails adds `image_processing` for Active Storage variants. TowerTrace never resizes images, and evidence files must not be transformed, so the gem (and its libvips system dependency) is removed.

### 5. Configuration from environment variables, no dotenv
`config/database.yml` and `config/storage.yml` read `POSTGRES_*` and `S3_*` variables. Development and test fall back to the same throwaway values as `.env.example`, so Rails runs natively against the Compose services with no extra gem. Docker Compose reads `.env` itself. Production has no credential fallbacks.

### 6. Test environment stores files on local disk
Tests use the Active Storage `Disk` service, so the suite and CI do not need MinIO. The MinIO path is exercised by running the Compose stack (and later by Playwright).

### 7. Evidence bucket has versioning on
`minio-init` creates the bucket with versioning, so even a delete or overwrite of an object keeps the prior version. This backs up the "originals are never modified" rule at the storage layer, not just in app code.

