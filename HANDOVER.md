# HANDOVER — Smart NGO M&E

**Current state snapshot.** Per-session narrative lives in `git log`; this file
describes the system as it stands and the things that are not obvious from the
code.

Last updated: 2026-07-22 · `main` @ local commit (unpushed) · tree clean

| | |
|---|---|
| Backend tests | **232 pass** (`pytest`, test_sqlite settings) |
| Flutter tests | **55 pass**, `flutter analyze` 0 issues |
| Swagger | `/api/v1/docs/` — 0 warnings, 0 errors |
| Phases | All 5 complete; work since then is post-phase improvement |

---

## Running it

```bash
# Backend (232 tests)
cd /Users/admin/Desktop/SmartNGO/backend && source venv/bin/activate
DJANGO_SETTINGS_MODULE=config.settings.test_sqlite pytest --tb=short -q

# Dev server + demo data
# Runs with --noreload: RESTART IT after any backend edit, or the browser
# keeps showing old behaviour while looking perfectly healthy.
DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py runserver 0.0.0.0:8000
DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py seed_demo  # idempotent

# Flutter (55 tests)
cd /Users/admin/Desktop/SmartNGO/mobile
flutter analyze && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Testing without MySQL uses `config.settings.test_sqlite`; the demo server uses
`local_sqlite`. Dev/prod settings still target MySQL.

**Left running**: Django on `:8000` (nohup, log `/tmp/smartngo-django.log`) and
the built web app on `:58569` (`python3 -m http.server -d mobile/build/web`),
both serving current code. Start background servers with `nohup … & disown` —
harness-tracked background tasks get reaped between turns.

**Demo logins** — `admin@demo.ngo`, `manager@demo.ngo`, `officer1@demo.ngo`,
`donor@demo.ngo`, `manager2@demo.ngo`; password `DemoPass123!` for all.

---

## What exists

**Backend** — Django 4.2 + DRF, 8 apps, 11 tables, JWT auth (15 min access /
7 day refresh, rotation + blacklist), bcrypt hashing, throttling, RBAC via
custom permission classes plus `ProjectScopedViewSetMixin` for NGO/assignment
scoping. Full CRUD for NGOs, projects (+ phases, assignments), beneficiaries,
indicators, milestones, reports (+ images, draft→submitted→approved workflow),
notifications (signal-driven), users, analytics dashboard, ReportLab PDFs, CSV
export, email verification, password reset.

**Structured donor reporting** (commit 1 of 3 — backend only) — `Report` gained
an activity type, optional links to a phase and a milestone, `amount_spent`,
a beneficiary breakdown (reached / male / female / youth), four narrative
fields, and `posted_at`. Every field is optional or defaulted, so older
reports stay valid.

- **Approval is what posts.** `apps/reports/services.py` holds `post_report` /
  `unpost_report`, both `transaction.atomic`. `posted_at` — not `status` — is
  the ledger flag, which makes both idempotent: approving twice cannot
  double-count, and un-approving something unposted is a no-op.
- Un-approving reverts a linked milestone **only** when
  `milestone.completed_by_report` is this report; a milestone ticked off by
  hand is left alone. New `POST /reports/{id}/unapprove/` (manager/admin)
  makes that reachable.
- `ProjectPhase.spent_budget` is now a **property**: `opening_spend`
  (the writable baseline, still the `spent_budget` DB column) plus
  `reported_spend` (approved reports). `Project` gained `reported_spend`,
  `beneficiaries_reached` and `cost_per_beneficiary`.
- Approved reports are **frozen** — editing any structured field returns 400,
  so the donor ledger stays append-only. Corrections mean a new report.
- Because spend is derived, `ProjectViewSet` prefetches `phases__reports` and
  `reports`; without it every serialized project re-queries per phase.

**Progress engine (EVM, per PMBOK)** — all computed properties on `Project`,
no caching, no stored aggregates:
- Composite progress = Financial×30% + Physical×50% + Time×20%.
- Financial = phase spend / budget. Physical = completed milestone *weight*
  share (weights 1–10). Time = calendar elapsed.
- **CPI** = physical / financial. **SPI** = physical / `planned_value_progress`
  (EV/PV). PV comes from the phase baseline: each phase contributes its
  allocated budget × the elapsed fraction of its own window. No phases or a
  non-positive budget → PV falls back to `time_progress`.
- `health_status`: both indices ≥0.95 healthy, ≥0.8 at_risk, else critical;
  either index `None` → not_started.

**Mobile** — Flutter web/mobile, 17 screens, GoRouter with role guards,
Provider, Dio + JWT refresh interceptor, sqflite offline report drafts,
fl_chart analytics, eCitizen/Kenya-government visual language (green #006633 +
gold #CC9900), Kenya 5-level location picker, shimmer loading everywhere.

---

## Gotchas worth keeping

**Environment**
- Dev server runs `--noreload`. Serializer/view/model edits do **not** hot-apply;
  restart before any browser check. This has silently produced misleading
  verification twice.
- `seed_demo` generates dates relative to today, so every reseed shifts every
  project/milestone date. Screenshots taken before a reseed drift by days —
  that is expected, not a bug.
- Reseeding after renaming seed rows needs a `flush` first; `get_or_create`
  otherwise duplicates them.
- Python 3.9 + Django 4.2 LTS + PyMySQL shim (see DECISIONS.md for why these
  differ from the CLAUDE.md spec).

**Backend**
- `makemigrations` cannot detect a field rename non-interactively — it offers
  RemoveField + AddField, which would **drop the column and its data**. The
  `opening_spend` rename is hand-written, and because `db_column` pins it to
  the existing column the whole thing is wrapped in
  `SeparateDatabaseAndState(database_operations=[])`: state-only, so
  `sqlmigrate` shows a no-op instead of two renames that cancel out (real
  churn on MySQL). Check `sqlmigrate` on any future rename.
- DRF serialises `DecimalField` as JSON **strings** — clients must parse
  tolerantly (`ProjectPhase.asDouble`, `Report._asDouble`).
- `DecimalField(max_digits=…)` validation fires **before** `validate_*`, so
  rounding must happen on a field declared without digit limits.
- The API takes `first_name`/`last_name`; `full_name` is a computed property,
  not a writable field.
- Existing CRUD endpoints return raw DRF payloads; only the five newer
  endpoints use the `{status, data, message}` envelope. Retrofitting would
  break the Flutter client — clients unwrap `resp.data["data"]` defensively.

**Flutter**
- A childless `ColoredBox` in a `Row` collapses to zero height — needs
  `crossAxisAlignment.stretch` (the flag ribbon).
- `Container` cannot take `color:` and `decoration:` together.
- `LayoutBuilder` cannot compute intrinsics — it crashes inside
  `IntrinsicHeight`; `ProjectProgressBar` uses `AnimatedFractionallySizedBox`.
- Fixed-height shimmer placeholders must adapt their line count to the height.
- A `Container` with no width shrink-wraps in a centred `Column` (the legend
  strip floated mid-card on the dashboard until given `width: double.infinity`).
- A bare `FractionallySizedBox` inside a `Stack` is sized to its factor and
  then positioned by the **Stack's** alignment — its own `alignment:` only
  places its child within itself. Left-anchored bars need an enclosing
  `Align` (this centred every band in `EvmProgressTrack`, and a width-factor
  unit test did not catch it — the regression test asserts geometry).
- All failure snackbars must route through `core/feedback.dart` — the default
  theme snackbar is success-green, so a raw error `SnackBar` reads as success.
- `/notifications` is **not** a GoRouter route; it is pushed with
  `MaterialPageRoute` from the dashboard bell.

**Driving the web app with puppeteer**
- **Verify every screenshot by eye.** A missed tap is a silent no-op, so a run
  can report "no console/API errors" and still capture the wrong screen.
- The notification bell must be tapped from a *settled* dashboard (~6s after
  the KPI fetches); earlier taps lose the route push to a re-render. Bell at
  (343, 40); officer "Submit Report" tile at (87, 467); back arrow at (24, 28).
- Login by keyboard at 430×932: Tab → email → Tab → password → Enter.
- Hash-navigate tab screens (`location.hash = '#/projects'`).
- Dropdowns with nothing selected align item 1 over the button; arrow-key
  counts are unreliable ±1. Lists need `mouse.wheel` or CDP touch — mouse drag
  does not scroll, and `RefreshIndicator` needs touch events.

---

## Known issues / deviations

1. Flat Flutter repo pattern instead of data/domain/presentation layers —
   accepted, DECISIONS.md D-006.
2. Web report drafts are in-memory; sqflite has no web implementation (D-010).
3. Reports bar chart shows counts by status, not a 6-month trend — the
   analytics endpoint exposes no monthly series.
4. Donor quick actions substitute View Analytics/Notifications for the spec's
   "Download PDF"; project PDFs are API-reachable but have no button.
5. "Member since" omitted from Profile — not in the `/auth/me/` payload.
6. Kenya location dicts are keyed by bare ward name, so same-named wards in
   different constituencies share one location list (1,282 unique names vs
   1,378 ward entries). A fix would key by (constituency, ward).
7. Milestone auto-overdue runs in the serializer's `to_representation`; there
   is no standalone cron command for it.
8. The dev DB has been flushed several times — manual accounts are gone; use
   the seeded demo logins.
9. **Temporary shim**: `ProjectPhaseSerializer.to_internal_value` maps a legacy
   `spent_budget` write onto `opening_spend`, because the shipped Flutter build
   still PUTs that field and silently dropping it would make phase edits vanish.
   Remove it in commit 3 once the app sends `opening_spend`.

---

## Docs screenshots

`docs/screenshots/` holds 15 app frames plus 2 Django verify-email pages, all
current as of 2026-07-21 against the reseeded data. The project detail screen
spans two files: `app-project-progress.png` (composite ring + dimension bars)
and `app-project-detail.png` (health card + phase table).

Regenerate with the puppeteer scripts in the session scratchpad
(`docshots.js <out-dir> [subset]`, `detailshot.js <out-dir> <scroll> <name>`,
`zoom.js` for a magnified crop), against a fresh `flutter build web` served on
`:58569`. Write to a temp dir, look at every frame, then copy into
`docs/screenshots/`.

Two capture lessons from this session:
- Allow ~12s after `goto` before typing. A fresh bundle boots slowly, and
  keystrokes sent early land nowhere — the run then screenshots the login
  screen and still reports no errors.
- Small UI details do not survive review at 430px. The EVM bands looked
  plausible in a full frame and were all centred instead of left-anchored;
  only the 4× `zoom.js` crop showed it.

---

## Next steps

0. Structured donor reporting, commits 2 and 3: the Flutter reporting form
   (structured fields, phase/milestone pickers) and the donor-facing report
   views. Commit 1 (backend) is done and deliberately invisible to the app.
1. Peterson: click through the app at http://localhost:58569 with the demo
   accounts and flag visual issues. Newest to review: the health card's
   earned-vs-planned line (project detail → Overview → scroll one screen) and
   the EVM tracks on the project register and dashboard rows.
2. Backlog: monthly report series endpoint for a real 6-month chart; donor PDF
   download button; user detail/edit screen; key the Kenya ward/location dicts
   by (constituency, ward).

## Blockers

None.
