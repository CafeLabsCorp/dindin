#!/usr/bin/env bash
# Dindin — gated production deploy.
#
# Encodes the MANDATORY release sequence from docs/BACKEND.md ("Deploy order")
# as a script instead of a checklist a human can skip a step of by hand:
#
#   1. Human confirms the manual data backup was taken (Ajustes -> Exportar
#      JSON, for every real user) — this is the only rollback for user data.
#   2. Dry-run the balance backfill and refuse to continue if it reports any
#      BALANCE CORRUPTION — a negative that should never exist (the account, a
#      'save' caixinha, or an orphan id). A legitimate open/frozen debt on an
#      allowNegative spend caixinha is a supported state and does NOT block.
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
#   - Firestore admin credentials for the backfill steps. Normally gcloud
#     Application Default Credentials, which this script picks up on its own:
#
#       gcloud auth application-default login
#       gcloud auth application-default set-quota-project dindin-cafelabs
#
#     A service-account JSON key also works via GOOGLE_APPLICATION_CREDENTIALS,
#     but creating one is blocked by org policy on this project — see the
#     credential block below. Never commit a key.
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

# Admin credentials for the backfill steps. Two supported shapes:
#
#   1. gcloud user ADC (the normal path here). `gcloud auth application-default
#      login` writes a credential file to a well-known location, which
#      firebase-admin's applicationDefault() accepts like any other. This is
#      the path to use because the GCP org policy on this project
#      (iam.disableServiceAccountKeyCreation) BLOCKS creating service-account
#      JSON keys outright — the console refuses, so option 2 is not reachable
#      unless someone lifts that policy.
#   2. A service-account key, if one is ever available.
#
# User credentials, unlike a service-account key, carry no project — hence the
# GOOGLE_CLOUD_PROJECT default below, without which firebase-admin cannot work
# out which Firestore to talk to.
ADC_DEFAULT="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/application_default_credentials.json"

if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$ADC_DEFAULT" ]; then
  log "Using gcloud Application Default Credentials ($ADC_DEFAULT)"
  export GOOGLE_APPLICATION_CREDENTIALS="$ADC_DEFAULT"
fi

if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  die "No admin credentials found. Run 'gcloud auth application-default login' followed by 'gcloud auth application-default set-quota-project $PROJECT_ID' (service-account JSON keys are blocked by org policy on this project), or export GOOGLE_APPLICATION_CREDENTIALS yourself if you do have a key."
fi
[ -f "$GOOGLE_APPLICATION_CREDENTIALS" ] || die "GOOGLE_APPLICATION_CREDENTIALS points at a file that does not exist: $GOOGLE_APPLICATION_CREDENTIALS"

# Harmless when the credential is a service-account key (which carries its own
# project); required when it is a user credential, which does not.
export GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-$PROJECT_ID}"

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
( cd "$SCRIPTS_DIR" && node backfill_balances.mjs --dry-run ) 2>&1 | tee "$DRY_RUN_LOG"

# Only BALANCE CORRUPTION aborts (a negative that should never exist: the
# account, a 'save' caixinha, or an orphan). A legitimate open/frozen debt on a
# spend caixinha with allowNegative is a supported state — the dry run prints it
# as an "open debt" warning WITHOUT this marker, so it does not block the deploy.
if grep -q "BALANCE CORRUPTION" "$DRY_RUN_LOG"; then
  rm -f "$DRY_RUN_LOG"
  die "Dry run reported a BALANCE CORRUPTION (see output above). Reconcile the affected ledger(s) before deploying — do not proceed."
fi
rm -f "$DRY_RUN_LOG"
log "Dry run clean — no balance corruption (legitimate open debts, if any, are fine)."

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
