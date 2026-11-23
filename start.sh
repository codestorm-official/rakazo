#!/usr/bin/env bash
# Derived from Rakazo's infra/railway/start.sh, Apache-2.0:
# https://github.com/elie222/rakazo/blob/v0.14.0/infra/railway/start.sh
#
# Changes for this template:
#   - builds DATABASE_URL from Railway Postgres variables so the deployer never has to
#     copy the generated runtime password into a second variable
#   - supports RAILWAY_SANDBOX_ENVIRONMENT_ID as an explicit override
#   - resolves the sandbox environment only when SANDBOX_PROVIDER=railway
set -euo pipefail
umask 077

if [[ $(id -u) == 0 ]]; then
  install -d -m 750 -o node -g node /data
  exec gosu node "$0" "$@"
fi

# The runtime login (rakazo_app) is subject to row-level security. Railway reference
# variables cannot be nested inside one composed value, so assemble the URL here from
# POSTGRES_APP_PASSWORD and the Postgres service's PG* variables. The generated password
# is hex, which is URL-safe.
if [[ -z "${DATABASE_URL:-}" ]]; then
  : "${POSTGRES_APP_PASSWORD:?Set POSTGRES_APP_PASSWORD}"
  : "${PGHOST:?Set PGHOST}"
  : "${PGPORT:=5432}"
  : "${PGDATABASE:?Set PGDATABASE}"
  export DATABASE_URL="postgres://rakazo_app:${POSTGRES_APP_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}"
fi

# Migrate as the database owner, then replace this shell without the owner login.
# Unsetting alone would leave it readable from /proc by any process running as node.
if [[ "${1:-}" != serve ]]; then
  if [[ -z "${DATABASE_MIGRATION_URL:-}" ]]; then
    echo "DATABASE_MIGRATION_URL is required (reference Postgres.DATABASE_URL)" >&2
    exit 1
  fi
  pnpm --filter @rakazo/api db:deploy
  exec env -u DATABASE_MIGRATION_URL bash "$0" serve
fi

# Bot computers run in a separate, empty Railway environment so they cannot reach this
# service's private database network. Reuse one when pinned; otherwise create or reuse
# the name derived from the project, service, and application environment.
if [[ -n "${RAILWAY_SANDBOX_ENVIRONMENT_ID:-}" ]]; then
  if [[ "${RAILWAY_SANDBOX_ENVIRONMENT_ID}" == "${RAILWAY_ENVIRONMENT_ID:-}" ]]; then
    echo "RAILWAY_SANDBOX_ENVIRONMENT_ID must differ from the application environment" >&2
    exit 1
  fi
  export RAILWAY_ENVIRONMENT_ID="${RAILWAY_SANDBOX_ENVIRONMENT_ID}"
elif [[ "${SANDBOX_PROVIDER:-}" == "railway" ]]; then
  export RAILWAY_ENVIRONMENT_ID
  RAILWAY_ENVIRONMENT_ID=$(node /usr/local/share/rakazo/sandbox-environment.mjs)
else
  unset RAILWAY_ENVIRONMENT_ID
fi

pnpm --filter @rakazo/api exec node dist/cli/bootstrap-owner.js
unset OWNER_PASSWORD
# Personal template: registration is operator configuration, never an app-account permission.
export SIGNUPS_ENABLED=false

# All processes share one volume; a failed process restarts the whole service.
trap 'kill $(jobs -pr) 2>/dev/null || true; wait || true' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
# The API is reached only through the web preview proxy on loopback. Railway's edge names the
# client in X-Real-IP, which that proxy passes on unchanged.
# Server installs encrypt content at rest unless the operator sets CONTENT_ENCRYPTION=off.
export CONTENT_ENCRYPTION="${CONTENT_ENCRYPTION:-on}"
export TRUSTED_PROXIES="${TRUSTED_PROXIES:-127.0.0.1}"
export CLIENT_IP_HEADER="${CLIENT_IP_HEADER:-x-real-ip}"
pnpm --filter @rakazo/api start &
pnpm --filter @rakazo/worker start &
(
  node --input-type=module -e '
  for (let attempt = 0; attempt < 60; attempt++) {
    const ready = await fetch("http://127.0.0.1:3100/ready", { signal: AbortSignal.timeout(2000) }).then(r => r.ok).catch(() => false);
    if (ready) process.exit(0);
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  throw new Error("API did not become ready");
'
  exec env -u RAILWAY_API_TOKEN -u DATABASE_URL -u ENCRYPTION_KEY -u ENCRYPTION_MASTER_KEYS -u OBJECT_STORAGE_SECRET_ACCESS_KEY -u OBJECT_STORAGE_CERTIFICATE -u BETTER_AUTH_SECRET \
    pnpm --filter @rakazo/web preview --host 0.0.0.0 --port 5173
) &
wait -n
exit 1
