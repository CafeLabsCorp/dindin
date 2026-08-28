#!/usr/bin/env bash
# Dindin — build a signed Android App Bundle (.aab) for the Google Play Console.
#
# This script does NOT upload anything and does NOT touch git. It builds the
# artifact and tells you where it is; the Play Console upload stays a deliberate
# manual step (see docs/DEPLOY.md, "Why the Play upload is manual").
#
# What it guards against, in order — these are the three ways a Play release
# actually goes wrong for a solo maintainer:
#
#   1. Building with the DEBUG key because android/key.properties is missing.
#      Play rejects the upload with a confusing "not signed with the upload
#      certificate" error after a 10-minute build. Caught here in 1 second.
#   2. Forgetting to bump versionCode. Play rejects any versionCode already
#      used by ANY previous upload, including internal-testing builds. This
#      script bumps it for you and shows you the resulting version.
#   3. Shipping an artifact that never ran the test suite.
#
# Usage:
#   scripts/release_android.sh              # bump versionCode by 1, build
#   scripts/release_android.sh --no-bump    # build with pubspec.yaml as-is
#   scripts/release_android.sh --version 1.1.0
#                                           # also set versionName to 1.1.0
#
# After it finishes, review `git diff pubspec.yaml` and commit the version bump
# — the script deliberately leaves committing to you.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$REPO_ROOT/pubspec.yaml"
KEY_PROPERTIES="$REPO_ROOT/android/key.properties"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31mABORTED:\033[0m %s\n' "$1" >&2; exit 1; }

BUMP=1
NEW_VERSION_NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-bump) BUMP=0; shift ;;
    --version) NEW_VERSION_NAME="${2:-}"; [ -n "$NEW_VERSION_NAME" ] || die "--version needs a value, e.g. --version 1.1.0"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# --- 1. signing preflight ----------------------------------------------------

log "Step 1/5 — signing preflight"
if [ ! -f "$KEY_PROPERTIES" ]; then
  die "android/key.properties not found — the build would be signed with the DEBUG key and Play would reject it.
Generate the upload keystore once (see docs/DEPLOY.md, 'Generate the upload key'), then:
  cp android/key.properties.example android/key.properties   # and fill it in"
fi

# Read storeFile without echoing any password to the terminal or to a log.
STORE_FILE="$(grep -E '^storeFile=' "$KEY_PROPERTIES" | head -1 | cut -d= -f2- || true)"
[ -n "$STORE_FILE" ] || die "android/key.properties has no storeFile= line."
[ -f "$STORE_FILE" ] || die "storeFile in android/key.properties points at a file that does not exist: $STORE_FILE"
case "$STORE_FILE" in
  "$REPO_ROOT"/*) die "The keystore is inside the repository ($STORE_FILE). Move it somewhere outside — this repo is public." ;;
esac
grep -qE '^storePassword=.+' "$KEY_PROPERTIES" || die "android/key.properties has an empty storePassword."
grep -qE '^keyPassword=.+'   "$KEY_PROPERTIES" || die "android/key.properties has an empty keyPassword."
echo "Upload keystore found at $STORE_FILE (passwords not printed)."

# --- 2. version -------------------------------------------------------------

log "Step 2/5 — version"
CURRENT_LINE="$(grep -E '^version: ' "$PUBSPEC" | head -1)"
CURRENT="${CURRENT_LINE#version: }"
CURRENT_NAME="${CURRENT%%+*}"
CURRENT_CODE="${CURRENT##*+}"
echo "pubspec.yaml currently at: $CURRENT_NAME+$CURRENT_CODE"

case "$CURRENT_CODE" in
  ''|*[!0-9]*) die "Could not parse a numeric versionCode out of 'version: $CURRENT'." ;;
esac

TARGET_NAME="${NEW_VERSION_NAME:-$CURRENT_NAME}"
if [ "$BUMP" -eq 1 ]; then
  TARGET_CODE=$((CURRENT_CODE + 1))
else
  TARGET_CODE="$CURRENT_CODE"
  warn "--no-bump: keeping versionCode $TARGET_CODE. Play will reject this if that code was ever uploaded before."
fi

if [ "$TARGET_NAME+$TARGET_CODE" != "$CURRENT_NAME+$CURRENT_CODE" ]; then
  # Only the first `version:` line at column 0 is rewritten; the explanatory
  # comment block above it (and any `version:` nested under a dependency) is
  # left alone.
  TMP_PUBSPEC="$(mktemp)"
  awk -v v="version: $TARGET_NAME+$TARGET_CODE" '
    !done && /^version: / { print v; done = 1; next }
    { print }
  ' "$PUBSPEC" > "$TMP_PUBSPEC"
  grep -qE "^version: $TARGET_NAME\+$TARGET_CODE$" "$TMP_PUBSPEC" \
    || { rm -f "$TMP_PUBSPEC"; die "Failed to rewrite the version line in pubspec.yaml; nothing was changed."; }
  mv "$TMP_PUBSPEC" "$PUBSPEC"
  echo "pubspec.yaml updated to: $TARGET_NAME+$TARGET_CODE"
else
  echo "pubspec.yaml left unchanged."
fi

# --- 3. tests ---------------------------------------------------------------

log "Step 3/5 — analyze + test (same checks CI runs)"
( cd "$REPO_ROOT" && flutter pub get && flutter analyze && flutter test )

# --- 4. build ---------------------------------------------------------------

log "Step 4/5 — building the release App Bundle"
# --release is the default for `build appbundle`, stated explicitly so nobody
# has to guess. No --obfuscate/--split-debug-info here on purpose: see
# docs/DEPLOY.md, "Obfuscation and symbol files" — the symbol files would have
# to be archived forever for crash reports to be readable, and there is no
# crash reporting wired up yet to make that trade worth it.
( cd "$REPO_ROOT" && flutter build appbundle --release )

AAB="$REPO_ROOT/build/app/outputs/bundle/release/app-release.aab"
[ -f "$AAB" ] || die "Build reported success but $AAB does not exist."

# --- 5. verify the signature is NOT the debug key ----------------------------

log "Step 5/5 — verifying the bundle is signed with the upload key"
if command -v keytool >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  SIGNER_CN="$(unzip -p "$AAB" 'META-INF/*.RSA' 2>/dev/null \
    | keytool -printcert 2>/dev/null | grep -m1 'Owner:' || true)"
  if [ -n "$SIGNER_CN" ]; then
    echo "Bundle signer -> $SIGNER_CN"
    case "$SIGNER_CN" in
      *"CN=Android Debug"*)
        die "This bundle is signed with the ANDROID DEBUG KEY. Play will reject it. Check android/key.properties." ;;
    esac
  else
    warn "Could not read the signer certificate from the bundle — verify manually before uploading."
  fi
else
  warn "keytool/unzip not on PATH; skipping the signer check."
fi

log "Done."
echo "Artifact: $AAB"
echo "Version:  $TARGET_NAME+$TARGET_CODE"
echo
echo "Next steps (manual, see docs/DEPLOY.md 'Upload runbook'):"
echo "  1. Review and commit the pubspec.yaml version bump."
echo "  2. Play Console -> Dindin -> Test and release -> pick a track -> Create"
echo "     new release -> upload the .aab above."
echo "  3. FIRST RELEASE ONLY: afterwards, copy the SHA-1 of the Play APP"
echo "     SIGNING key (Play Console -> Test and release -> Setup -> App"
echo "     signing) into the Firebase console, or Google Sign-In will fail for"
echo "     every user who installs from Play."
