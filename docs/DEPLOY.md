# Deploy, CI, and rollback

**[Leia em Português](DEPLOY.pt-br.md)**

Operational guide for a solo maintainer running/debugging Dindin's deploy
without rebuilding context. Read `docs/BACKEND.md` first for *why* the deploy
order is what it is — this file is the *how*, plus CI and rollback.

Two distribution channels ship from this one repository, and they behave
nothing alike:

| | Web (Firebase Hosting) | Android (Google Play) |
|---|---|---|
| How | `scripts/deploy.sh` / `firebase deploy` | `scripts/release_android.sh` + a manual Play Console upload |
| Time to users | seconds | minutes to days (Google review) |
| Rollback | a few clicks, instant | **none** — see "Rollback on Play" |
| Cost | free (Spark) | US$25 one-time, already paid |

Because of that third row, the Android section is worth reading in full before
the first upload rather than during it.

## CI (`.github/workflows/ci.yml`)

Runs on every push to `main`, plus manually via "Run workflow"
(`workflow_dispatch`). Three independent jobs. **Cost: zero and uncapped** —
`github.com/CafeLabsCorp/dindin` is a public repository, so Actions minutes are
unmetered and there is no billing surface here at all. (If it were ever made
private, the free cap is 2,000 min/month and the `android` job below is the
expensive one, ~10 min per run.)

- **`flutter`** — `flutter pub get && flutter analyze && flutter test`.
  Platform-agnostic: it does **not** compile the Android or Windows target.
- **`rules`** — spins up the Firestore emulator (`firebase-tools
  emulators:exec`) and runs `npm test` in `test/rules/`, which is
  `rules.test.mjs` (Security Rules — Phase-2 money-integrity, including the
  `getAfter()`/null-teardown paths that can't be exercised from Dart; dozens
  of cases across 8 `describe` blocks) **and** `backfill.test.mjs`
  (`scripts/backfill_balances.mjs`'s legitimate-debt-vs-corruption
  classification, run as a real subprocess against the same emulator), both
  in one pass. Uses the emulator only — never touches production, needs no
  project credentials.
- **`android`** — `flutter build appbundle --release`. Because `flutter
  analyze`/`flutter test` never touch Gradle, without this job a broken
  manifest, plugin or AGP upgrade is only discovered on release day, by hand,
  under time pressure. It holds **no secrets**: `android/key.properties` is not
  in the repo, so the build falls back to the debug key (which also proves that
  fallback still works for fresh clones) and the resulting bundle is
  deliberately *not* published as an artifact — a debug-signed `.aab` is
  useless and nobody should be tempted to upload one. It also asserts that
  `pubspec.yaml`'s version line still parses as `<name>+<code>`.

CI does **not** deploy anything — not to Firebase Hosting, not to Google Play.
It's a safety net for the code; shipping to production is still the deliberate
manual action below.

To debug a CI failure locally, run the same commands: `flutter analyze`,
`flutter test`, `flutter build appbundle --release`, or `firebase
emulators:exec --only firestore --project dindin-rules-test "npm test --prefix
test/rules"` (see the header of `test/rules/rules.test.mjs` for the
two-terminal manual variant).

### Why the Play upload is manual

Deliberate call, not an unfinished one. Automating it would mean putting the
**upload keystore and its passwords into GitHub Actions secrets**, plus a
long-lived Google service-account key for the Play Developer API — moving the
one secret whose compromise is genuinely expensive into a second location,
controlled by a third party, on a *public* repository, to save about two
minutes of a first-release process that is otherwise several hours of manual
console work (identity verification, store listing, data safety form, content
rating, a 14-day closed test). At an MVP release cadence of weeks, that
automation would rot before it ever paid for itself, and the first execution of
a release path should be one a human watched end to end.

Revisit when releases become weekly or faster, or when a second person needs to
be able to ship. At that point the shape to use is a `workflow_dispatch`-only
job with `fastlane supply` and a base64 keystore in Actions secrets — not a
push-triggered one.

## Deploying (`scripts/deploy.sh`)

Encodes the mandatory release order from `docs/BACKEND.md` as a script with
hard gates, so a step can't be skipped or reordered by accident:

1. Interactive confirmation that the manual data backup (Ajustes -> Exportar
   JSON, per real user) was taken. Aborts if not confirmed.
2. Dry-run backfill (`backfill_balances.mjs --dry-run`); aborts if the output
   contains the marker `BALANCE CORRUPTION` — a negative balance that should
   never exist (the general account, a `save` caixinha, or an orphan id). A
   legitimate open/frozen debt on a `spend` caixinha (the `allowNegative`
   feature) prints as an "open debt" warning WITHOUT that marker and does
   NOT block the deploy — see `docs/BACKEND.md`, "Option B residual
   limitations" for how the script tells the two apart.
3. Final interactive confirmation before any real writes/deploys.
4. Real backfill run (idempotent).
5. Preflight: `backfill_balances.mjs --verify` — confirms every
   `/users/{uid}` has a `meta/account` doc. Aborts before touching rules if
   anyone is missing one.
6. `firebase deploy --only firestore:rules --project dindin-cafelabs`.
7. `flutter build web` + `firebase deploy --only hosting --project
   dindin-cafelabs`.

Run it from the repo root:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project dindin-cafelabs
scripts/deploy.sh
```

`deploy.sh` picks those credentials up on its own — nothing to export.

**Why ADC rather than a service-account key:** the org policy on this project
(`iam.disableServiceAccountKeyCreation`) **blocks** creating service-account
JSON keys. The console refuses with "Key creation is not allowed on this
service account", so the key path isn't available unless someone lifts that
policy. A user credential via ADC works the same for `firebase-admin`, with
one difference: it carries no project of its own, so `GOOGLE_CLOUD_PROJECT`
is required — the script handles that. If you do have a key from elsewhere,
`export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/serviceAccount.json`
still works (never commit it).

The org also enforces periodic reauthentication: if you see `invalid_rapt` or
`invalid_grant`, just re-run `gcloud auth application-default login`.

This script is meant for interactive, by-hand use during a release — it is
not run in CI. If you only need to publish a hosting-only change (no rules/
schema change), the old manual sequence is still valid and safe:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

(Skip `scripts/deploy.sh` entirely for pure UI changes — the backup/backfill
gate exists specifically for changes that touch `firestore.rules` or the
balance docs, not every deploy.)

## Android release (Google Play)

Web and Android ship from this same repository, but through two pipelines with
opposite properties. The web deploy is reversible in a few clicks; **a Play
release is not reversible at all** — see "Rollback on Play" below. Read that
part before the first upload, not after.

### Two keys, and only one of them is yours

New Play apps use **Google Play App Signing**, which is not optional. That
splits signing into two keys, and confusing them is the single most expensive
mistake available here:

| | Upload key | App signing key |
|---|---|---|
| Who holds it | You (Felipe), in the keystore you generate below | Google, in Play Console. You never see the private key |
| What it signs | The `.aab` you upload | The APKs Google generates and delivers to devices |
| If lost | Recoverable — Play support resets it and you register a new one. Days of friction, not fatal | Never lost, never changed, never replaceable |
| Where its SHA-1 matters | Local builds and `flutter run` | **Every install that came from Play** |

Practical consequences:

1. **Back up the upload keystore anyway** (below). "Recoverable via support" is
   not something you want to discover you need on the day of a hotfix.
2. **Google Sign-In is registered against the wrong key by default.** Play
   re-signs the app with the *app signing key*, so the SHA-1 Firebase must
   know about is the app signing key's, taken from the Play Console after the
   first upload. If only your upload/debug key's SHA-1 is registered, sign-in
   works perfectly on your machine and fails with `ApiException: 10
   (DEVELOPER_ERROR)` for every single user who installed from the store. This
   is currently unregistered — see "Blocking before the first upload".

### Generate the upload key (once, by the maintainer only)

Nobody else — no agent, no CI, no collaborator — should ever run this or hold
the result. Run it once, on your own machine, outside the repository:

```bash
mkdir -p ~/keys/dindin
keytool -genkey -v \
  -keystore ~/keys/dindin/dindin-upload-key.jks \
  -storetype JKS \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias upload
```

`keytool` ships with the JDK (already installed for the Firestore emulator).
It prompts for a keystore password, a key password, and a distinguished name
(your name / org / city are fine; none of it is shown to users). `-validity
10000` is ~27 years — Play requires the certificate to stay valid well past
2033, so do not shorten it. `keytool` will warn that JKS is a proprietary
format; PKCS12 (`-storetype PKCS12`) works equally well with Gradle if you
prefer, just keep the path in `key.properties` in sync.

Then point the build at it:

```bash
cp android/key.properties.example android/key.properties
# edit android/key.properties: absolute storeFile path + the two passwords
```

`android/key.properties` is gitignored in two places (`android/.gitignore` and
the repo-root `.gitignore`) and **this repository is public** — never move the
keystore into the working tree, never paste a password into a commit, an
issue, or a CI log. `scripts/release_android.sh` refuses to build if the
`storeFile` path resolves inside the repo.

`android/app/build.gradle.kts` reads that file. If it is absent — a fresh
clone, CI, anyone who is not you — release builds fall back to the debug key
and print a loud warning instead of failing, so the project still builds and
tests for everyone else. A debug-signed bundle is rejected by Play, so the
fallback cannot quietly produce a "real" release.

### Back up the keystore

The keystore file **and** its passwords are one unit: a keystore whose password
is gone is a lost keystore. Back up both, in a place that is not this repo and
not a git repository at all (git never forgets a file, even one deleted later):

- The `.jks` file → the company Google Drive, same reasoning as the contract
  PDFs, plus one offline copy (USB/external disk).
- The two passwords and the alias (`upload`) → the password manager, as an
  entry that also links to where the `.jks` lives.
- Record the fingerprints too, so you can identify the key later without
  opening it:
  ```bash
  keytool -list -v -keystore ~/keys/dindin/dindin-upload-key.jks -alias upload
  ```

**Test the restore once.** Download the backup copy to a scratch directory and
run the `keytool -list -v` above against *that copy*, with the password read
from the password manager. A backup that has never been opened is a hypothesis,
not a backup.

### Versioning

`pubspec.yaml`'s `version: <versionName>+<versionCode>` feeds both channels,
but the two halves do not mean the same thing:

- **`versionName`** (`1.0.0`) — the product's semantic version, shared by Web,
  Android and Windows. This is the human-facing number.
- **`versionCode`** (`+1`) — **Android only**. A monotonic counter of artifacts
  uploaded to Play. Play refuses any upload whose code is not strictly greater
  than every code ever uploaded for this app, *including* builds that only went
  to internal testing and builds that were rejected. It can never be reused or
  lowered for the lifetime of the listing.

So: `flutter build web` ignores `versionCode` entirely. Bumping it without
shipping web, or shipping web without bumping it, are both normal — it counts
Play uploads, not product releases. Do not switch to a date-based code
(`20260827`): it caps you at one upload per day and burns the integer space
irreversibly.

**First Play release: `1.0.0+1`.** Nothing has ever been uploaded, so code 1 is
still free. `scripts/release_android.sh` bumps the code for you; CI checks the
line still parses as `<major>.<minor>.<patch>+<code>`.

### Build the App Bundle

Play requires an **Android App Bundle** (`.aab`) for new apps. `flutter build
apk` is only for sideloading and direct distribution — never for the store.

The scripted path, which is the one to use:

```bash
scripts/release_android.sh                 # bump versionCode by 1, then build
scripts/release_android.sh --version 1.1.0 # also set a new versionName
scripts/release_android.sh --no-bump       # rebuild the same versionCode
```

It refuses to start without `android/key.properties`, refuses a keystore stored
inside the repo, bumps `pubspec.yaml`, runs the same `analyze`/`test` CI runs,
builds, and then reads the signer certificate back out of the produced bundle
to prove it is not debug-signed. It does not commit, does not push, and does
not upload anything. Review `git diff pubspec.yaml` and commit the bump
yourself.

The manual equivalent, if you need to debug a step of it:

```bash
flutter pub get
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
unzip -p build/app/outputs/bundle/release/app-release.aab 'META-INF/*.RSA' \
  | keytool -printcert | head -2      # must NOT say CN=Android Debug
```

The bundle is ~60 MB, but that is not the download size: roughly half of it is
per-ABI debug symbol metadata that Play strips before delivery, and Play then
serves each device only its own ABI. Expect users to download well under
20 MB.

**Release builds are minified and resource-shrunk (R8); debug builds are not.**
What R8 removed is listed in `build/app/outputs/mapping/release/usage.txt`.
That is a real behavioural difference from every build ever run on this app so
far, so before the first upload, install the release artifact on a physical
device and exercise Google Sign-In, a Firestore read and write, and the JSON
export/import round trip. `flutter build apk --release` + `adb install` is the
quickest way to test the same code path (the AAB itself is not directly
installable; `bundletool build-apks --local-testing` is the exact-fidelity
alternative if you want it).

### Obfuscation and symbol files — deliberately off

`--obfuscate --split-debug-info` is **not** used here, and this is a decision
rather than an omission:

- The AAB already ships full native debug symbols to Play, per ABI
  (`BUNDLE-METADATA/com.android.tools.build.debugsymbols/*/libapp.so.sym`) plus
  the R8 mapping (`.../obfuscation/proguard.map`). Play Console symbolicates
  crash reports from those automatically, with zero archival work from you.
- Turning obfuscation on moves Dart symbol resolution *out* into
  `app.android-arm64.symbols` files that would have to be archived, per
  release, forever, next to the keystore backup. Lose them and every crash
  report from that version is permanently unreadable. That is a brand-new
  unrecoverable failure mode for a solo maintainer, bought with very little.
- There are no client-side secrets to protect. The Firebase config in
  `lib/firebase_options.dart` and `android/app/google-services.json` is public
  by design; the access boundary is `firestore.rules` (see `docs/BACKEND.md`),
  which obfuscation does nothing for.

Revisit only when a crash reporter (Crashlytics/Sentry) is wired up *and*
symbol upload is automated. If you do turn it on, the command is
`flutter build appbundle --release --obfuscate
--split-debug-info=~/keys/dindin/symbols/<versionName>+<versionCode>/` — note
the path is outside the repo, versioned per build, and must be backed up with
the same discipline as the keystore.

### Upload runbook (first release)

Steps 1 and 2 are gated on Google and are the long pole — start them before
anything else.

1. **Identity verification.** The developer account is an individual account
   (Felipe Portes Antunes, opened 2026-08-25). Until Google finishes verifying
   identity and address, you cannot even create the app entry. Nothing below
   is actionable until this clears.
2. **Closed-testing requirement.** Individual accounts created after
   2023-11-13 must run a closed test with a minimum number of opted-in testers
   for 14 continuous days before they can apply for production access. Google
   has changed the tester count at least once (it was 20, then 12) — read the
   current number in your own Play Console rather than trusting this document.
   Budget ~3 weeks of calendar time and recruit testers now; this is almost
   always what actually delays a first launch.
3. **Create the app** in Play Console: name, default language (pt-BR), app (not
   game), free.
4. **Store listing assets** — none of these live in this repo, all are uploaded
   in the console:
   - app icon, 512x512 32-bit PNG, no transparency, no pre-rounded corners
     (generate from `assets/icon/logo_1024.png`);
   - feature graphic, 1024x500;
   - at least 2 phone screenshots;
   - short description (80 chars) and full description (4000);
   - **a public privacy policy URL** — mandatory here, because the app requires
     an account and handles financial data. `dindin.cafelabs.net` is the
     natural host. This is a hard blocker with no workaround.
5. **Data safety form.** Declare, at minimum: email address and name (collected
   via Firebase Auth / Google Sign-In) and financial information (the
   user-entered ledger), stored on Firebase, encrypted in transit. Apps that
   let users create an account must also provide an **account deletion path**
   — both in-app and as a public web URL. Verify one exists before filling this
   in; a false declaration here is a policy violation, not a paperwork slip.
6. **Content rating** questionnaire, **target audience**, ads declaration (no
   ads).
7. **Upload the `.aab`** to a track: Test and release → (Internal testing →
   Closed testing → Production) → Create new release → upload
   `build/app/outputs/bundle/release/app-release.aab`.
8. **Immediately after the first upload**, before letting anyone install it:
   Play Console → Test and release → Setup → App signing → copy the **SHA-1 of
   the app signing key certificate** → Firebase console → Project settings →
   your Android app → Add fingerprint → paste → **re-download
   `google-services.json` into `android/app/`** and commit it. Without this,
   Google Sign-In fails for every store install. Add your upload key's SHA-1
   too, so locally built release APKs keep working.
9. **Roll out in stages**, not at 100% — see below.

For a later, routine release, only steps 7 and 9 apply.

### Rollback on Play — there isn't one

Say it plainly, because the web-hosting habit does not transfer: **you cannot
un-publish, delete, or roll back a version that has reached users.** Anyone who
already updated has the broken build and Play will not take it away from them.

The three levers that do exist:

- **Halt rollout.** Only meaningful if the release is on a *staged* rollout: it
  stops distribution to new users at whatever percentage you reached. Users who
  already got it keep it. This is the closest thing to a rollback and it only
  exists if you chose a staged rollout beforehand.
- **Roll forward.** Fix, bump `versionCode`, upload, release. This is the real
  recovery path. Best case it is an hour; a new release can also sit in Google's
  review for a day or more, and you have no control over which.
- **Re-release the previous build.** Allowed, but the old `versionCode` is burnt
  forever — you must upload that same code under a *new*, higher `versionCode`.

Which means, operationally:

- **Always use a staged rollout** (start around 10–20%, watch Android vitals for
  a day, then widen). It is free, it is the only rollback-shaped tool Play
  gives you, and it is chosen at release time — you cannot add it afterwards.
- **The web app is the fast-fix channel.** `app.dindin.cafelabs.net` runs the
  same code against the same Firestore data and the same accounts, and rolls
  back in a few clicks. If an Android release is broken and a fix is stuck in
  review, pointing affected users at the web app is a real mitigation.
- **A `firestore.rules` regression breaks both clients at once**, and only the
  rules rollback (below) fixes it — rolling forward on Android would not, and
  could not arrive fast enough anyway. That asymmetry is the reason rules
  changes go through `scripts/deploy.sh` and not through an app release.

### And the data still does not roll back

Everything in "User data" below applies unchanged, only worse: a web release
that corrupts data can be stopped in minutes, an Android one cannot be pulled
back from the devices already running it. The per-user JSON export taken at
`scripts/deploy.sh` step 1 remains the only restore path — take it before an
Android release that touches the ledger schema too, even though the Android
release itself does not run that script.

## Rollback

### Firestore rules

The previous rules file lives in git history — this is the whole rollback
path, no separate backup needed:

```bash
git log --oneline -- firestore.rules        # find the last-good commit
git show <good-commit>:firestore.rules > firestore.rules
firebase deploy --only firestore:rules --project dindin-cafelabs
git checkout -- firestore.rules             # restore the working tree after
```

This only touches rules — it does not affect the balance docs written by the
backfill, which stay valid under either rules version (Phase 1 rules simply
don't check them).

### Hosting (web client)

Firebase Hosting keeps prior releases automatically. To roll back without a
rebuild:

- Firebase console -> Hosting -> your site -> "Release history" -> pick the
  previous release -> **Rollback**. This is a few clicks, no CLI needed, and
  is the fastest path back to a known-good client.
- Or from the CLI: `firebase hosting:clone <site>:<previous-release-id>
  <site>:live --project dindin-cafelabs`.

### User data

The **only** rollback for user data is the manual JSON export taken during
the deploy-gate backup step (`scripts/deploy.sh` step 1 / `docs/BACKEND.md`).
To restore: open the app, sign in as the affected user, Ajustes -> Importar
JSON, pick the backup file. This replaces that user's six ledger
collections and resets their balance docs from the imported ledger — there
is no partial/selective restore, so use the most recent good export.

There is no automated point-in-time backup of Firestore itself (Spark/free
tier has no scheduled export product) — the per-user JSON export is the
entire data-durability story right now. If usage grows enough that "ask each
user to have exported recently" stops being an acceptable bar, revisit a
scheduled export (Blaze-tier `gcloud firestore export` to Cloud Storage, or a
scripted Admin-SDK dump) — out of scope for this MVP cycle.

## Monitoring — current gap, recommended next step (not set up in this cycle)

This cycle's scope was CI + the backup/rollback gate. Flagging explicitly:
**there is currently no uptime or error-rate visibility on the live app** —
an outage or a spike in rejected writes (e.g. from a rules regression) would
only be discovered from a user report. That's an acceptable, deliberate gap
for the code changes going out *this* cycle (rules changes are additive/
backward-compatible per `docs/BACKEND.md` and were verified against the
emulator), but it should not stay unaddressed for long as real users rely on
this app. Cheapest options, in order of effort:

- **Uptime**: a free external monitor (e.g. UptimeRobot free tier — 50
  monitors, 5-minute interval, email/webhook alert) pointed at
  `https://dindin-cafelabs.web.app`. Takes about 5 minutes to set up and
  needs no code change; requires only creating an account, so it's left for
  the owner rather than done silently here.
- **Errors**: Firebase Crashlytics (free, already-integrated Firebase
  product) for client-side errors, or watching the Firebase console's
  Firestore "Rules" usage/denials panel after a rules deploy to catch a
  spike in rejected writes.
- **Usage/cost**: see the next section — the distinction between a brake and a
  warning matters more here than it looks.

### Free-tier limits: what stops automatically and what only warns you

Two independent services, and they fail in opposite ways.

**Firebase (Spark).** No billing account is attached, so **a surprise bill is
impossible** — the daily quotas are a hard stop, not a soft one. That hard stop
*is* the brake, and it is automatic. What you do not get by default is any
warning before you hit it. The caps that matter (verify current numbers in the
console, Google adjusts them):

| Quota | Spark daily cap | What happens at the cap |
|---|---|---|
| Firestore document reads | ~50,000/day | reads start failing until 00:00 US-Pacific |
| Firestore document writes | ~20,000/day | writes start failing until 00:00 US-Pacific |
| Firestore deletes | ~20,000/day | deletes start failing |
| Stored data | 1 GiB | writes rejected |
| Auth (Google Sign-In) | no daily cap | — |

This is exactly the shape the abuse patterns `backend`/`security` guard against
arrive in: a script creating accounts in a loop, or hammering writes, burns
20,000 writes long before it costs anything — and then **the app goes down for
every real user until UTC-ish midnight**, with no bill and, by default, no
notification. The failure mode of a free tier is an outage, not an invoice.

What to actually set up, in order of value:

1. **The external uptime monitor** (UptimeRobot, above) is the one that would
   catch this, because quota exhaustion makes the web app visibly error. It is
   an after-the-fact alarm, but it is the only one that works today with no
   caveats. Set it up.
2. **Firebase console → Usage and billing → Usage** shows the daily counters.
   Worth a look the day after any launch or announcement. Manual.
3. **Cloud Monitoring alert policies** on Firestore metrics
   (`firestore.googleapis.com/document/write_count`) would give a *predictive*
   alert at, say, 60% of the daily write quota. **Verify this before relying on
   it**: alerting policies on a GCP project with no billing account attached
   are not guaranteed to be available, and Firebase's own budget alerts
   definitely require Blaze. If the console refuses, fall back to 1 and 2 —
   do not enable Blaze to get the alert, since attaching a billing account
   removes the hard cap that is currently the only thing preventing a bill.

**GitHub Actions.** Public repository → unmetered minutes, no billing surface,
nothing to alert on.

**Google Play.** One-time US$25 developer registration, already paid. No
per-install or per-download cost, ever. Nothing to monitor financially.

### Android-specific monitoring (after the first release)

- **Play Console → Quality → Android vitals** is free and automatic: crash
  rate, ANR rate, and stack traces already symbolicated (the AAB ships debug
  symbols, see "Obfuscation and symbol files"). Turn on email alerts in Play
  Console → Settings → Preferences → Email notifications, including the
  "bad behaviour threshold" ones — exceeding ~1.09% user-perceived crash rate
  gets the listing demoted in search and recommendations.
- **Play Console → Reviews** with email notifications on. For a solo
  maintainer this is, realistically, the fastest outage signal for the Android
  client specifically.
- **Still missing**: no Crashlytics/Sentry, so errors that do not crash the
  process (a failed Firestore write, a sign-in that silently does nothing) are
  invisible on both clients. That is the main remaining monitoring gap and the
  right next investment after the launch settles.
- Firebase itself has no uptime endpoint of ours to poll — the client talks to
  Google directly. Subscribe to https://status.firebase.google.com for
  platform-side incidents.

## Settle before the first Play upload (some of it is permanent)

- **Package name `com.cafelabs.dindin`** — permanent. It cannot be changed
  after publication, and it cannot be reused even if you delete the app entry
  and start over. It matches `namespace`, `applicationId`, and the package in
  `android/app/google-services.json`. Confirm you are happy with it *now*.
- **Google Sign-In SHA-1 is not registered at all.**
  `android/app/google-services.json` currently has an empty `oauth_client`
  list, which means no certificate fingerprint is registered for the Android
  app in Firebase — sign-in will fail on device today, and will keep failing
  for Play installs until the *app signing key* SHA-1 is added (see step 8 of
  the upload runbook). Treat this as a launch blocker.
- **`android:label`** is now `"Dindin"` (was the lowercase template value
  `dindin`). This is only the launcher label; the Play listing title and
  `web/index.html`'s `<title>` are two separate strings — `web/index.html`
  still says `dindin`. Pick one spelling across all three. This one is
  changeable later, unlike the package name.
- **App icon** — the adaptive icon is correctly configured (foreground inset
  16%, background `#FCFCFB`), so the launcher icon is fine. Play separately
  requires a 512x512 32-bit PNG store icon uploaded in the console, with no
  transparency and no rounded corners baked in.
- **Privacy policy URL and account-deletion path** — both mandatory for an app
  with accounts and financial data, both blocking, and neither exists in this
  repo. See steps 4 and 5 of the upload runbook.
