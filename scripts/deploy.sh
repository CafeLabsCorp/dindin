#!/usr/bin/env bash
# Dindin — gated production deploy.
#
# Encodes the MANDATORY release sequence from docs/BACKEND.md ("Deploy order")
# as a script instead of a checklist a human can skip a step of by hand:
#
#   1. Human confirms the manual data backup was taken (Ajustes -> Exportar
#      JSON, for every real user) — this is the only rollback for user data.
#   2. Dry-run the balance backfill and refuse to continue if it reports any
#      NEGATIVE BALANCE (must be reconciled in the ledger first).
#   3. Final human confirmation.
#   4. Real backfill run (idempotent, safe to re-run).
#   5. Preflight: verify every /users/{uid} has a meta/account doc — if the
#      backfill missed anyone, the Phase-2 rules would lock them out of
#      writes the instant they land. Abort before touching rules if this
#      fails.
#   6. Deploy firestore.rules.
#   7. Build the web client and deploy hosting.
#
# This script is meant to be run interactively, by hand, by whoever is doing
# the release. It is NOT run by CI — CI (.github/workflows/ci.yml) only
# analyzes/tests; shipping to production stays a deliberate manual action.
#
# Requires:
#   - `firebase` CLI on PATH, logged in with deploy access to dindin-cafelabs.
#   - GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key with
#     Firestore admin access (see scripts/backfill_balances.mjs header for how
#     to generate one). Never commit this key.
#
# Usage: scripts/deploy.sh

set -euo pipefail

PROJECT_ID="dindin-cafelabs"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31mABORTED:\033[0m %s\n' "$1" >&2; exit 1; }

confirm() {
  # $1 = prompt text. Returns 0 only on an explicit "s"/"y".
  local reply
  read -r -p "$1 [s/N] " reply || true
  case "$reply" in
    [sSyY]) return 0 ;;
    *) return 1 ;;
  esac
}

# --- sanity checks -----------------------------------------------------------

command -v firebase >/dev/null 2>&1 || die "firebase CLI not found on PATH. Install firebase-tools first."

if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  die "GOOGLE_APPLICATION_CREDENTIALS is not set. Export it to point at the Firestore admin service-account key (see scripts/backfill_balances.mjs header). Never commit this key."
fi
[ -f "$GOOGLE_APPLICATION_CREDENTIALS" ] || die "GOOGLE_APPLICATION_CREDENTIALS points at a file that does not exist: $GOOGLE_APPLICATION_CREDENTIALS"

if [ ! -d "$SCRIPTS_DIR/node_modules" ]; then
  log "Installing scripts/ dependencies (firebase-admin)..."
  (cd "$SCRIPTS_DIR" && npm install)
fi

# --- 1. human backup gate ----------------------------------------------------

log "Step 1/6 — manual data backup"
echo "Before touching production: sign in as EACH real user in the app and do"
echo "Ajustes -> Exportar JSON, saving each .json file somewhere durable."
echo "This export is the only rollback for user data (see docs/DEPLOY.md)."
confirm "Have you already done this backup for every real user?" \
  || die "Backup not confirmed. Do the export first, then re-run this script."

# --- 2. dry-run backfill + negative-balance gate -----------------------------

log "Step 2/6 — backfill dry run"
DRY_RUN_LOG="$(mktemp)"
( cd "$SCRIPTS_DIR" && node backfill_balances.mjs --dry-run ) | tee "$DRY_RUN_LOG"

if grep -q "NEGATIVE BALANCE" "$DRY_RUN_LOG"; then
  rm -f "$DRY_RUN_LOG"
  die "Dry run reported a NEGATIVE BALANCE (see output above). Reconcile the affected ledger(s) before deploying — do not proceed."
fi
rm -f "$DRY_RUN_LOG"
log "Dry run clean — no negative balances."

# --- 3. final confirmation ---------------------------------------------------

log "Step 3/6 — final confirmation"
echo "About to, in order, against project '$PROJECT_ID':"
echo "  a) run the REAL backfill (writes meta/account + balances/{catId})"
echo "  b) verify every user has a meta/account doc"
echo "  c) deploy firestore.rules"
echo "  d) build the web client and deploy hosting"
confirm "Proceed?" || die "Cancelled by user."

# --- 4. real backfill ---------------------------------------------------------

log "Step 4/6 — running real backfill"
( cd "$SCRIPTS_DIR" && node backfill_balances.mjs )

# --- 5. preflight verify ------------------------------------------------------

log "Step 5/6 — verifying every user has meta/account before deploying rules"
( cd "$SCRIPTS_DIR" && node backfill_balances.mjs --verify ) \
  || die "Verify failed — some user is missing meta/account. Rules NOT deployed. Investigate before retrying."

# --- 6. deploy rules, then build + deploy hosting ----------------------------

log "Step 6/6 — deploying firestore.rules"
( cd "$REPO_ROOT" && firebase deploy --only firestore:rules --project "$PROJECT_ID" )

log "Building web client"
( cd "$REPO_ROOT" && flutter build web )

log "Deploying hosting"
( cd "$REPO_ROOT" && firebase deploy --only hosting --project "$PROJECT_ID" )

log "Deploy complete."
echo "If anything looks wrong post-deploy, see the rollback steps in docs/DEPLOY.md."
