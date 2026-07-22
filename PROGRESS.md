# PROGRESS — Smart NGO M&E Application

**Current state snapshot.** Dated per-session entries live in `git log`.

Last updated: 2026-07-22 · `main` @ `ba82975` (pushed)
**Backend 274 tests · Flutter 88 tests · `flutter analyze` 0 issues**

**All 5 build phases complete — the project is assessment-ready.** Everything
since is post-phase improvement.

| Phase | Title | Status |
|-------|-------|--------|
| 1 | Backend Foundation | ✅ Complete |
| 2 | Core API | ✅ Complete |
| 3 | Advanced Backend Features | ✅ Complete |
| 4 | Flutter App | ✅ Complete — all 17 screens |
| 5 | Quality Assurance & Polish | ✅ Complete |

---

## Backend

**Foundation** — Django 4.2 + DRF, split settings (base/dev/prod/ci/test_sqlite),
custom email-login `User` with role enum + NGO FK + soft delete, 11 tables
across 8 apps, all migrations applied.

**Auth & security** — JWT (15 min / 7 day, rotation, blacklist), bcrypt with
PBKDF2 fallback, throttling (20/min anon, 100/min user), password reset
(`secrets.token_urlsafe`, SHA-256 stored, 1 hr TTL, single-use), email
verification, custom permission classes (IsSystemAdmin, IsProjectManager,
IsFieldOfficer, IsDonor, IsSameNGO, ReadOnly), `{error, code}` exception
envelope, security boundary suite (cross-role denial, token expiry/tamper,
blacklisted refresh, rate limiting, multi-tenant isolation).

**Resources** — NGOs, projects (+ phases, assignments), beneficiaries (computed
age, CSV export), indicators (computed progress), milestones (auto-overdue in
`to_representation`, weights 1–10), reports (draft→submitted→approved, officer
preserved) + images (MIME + 5 MB + 5-per-report), notifications, users,
analytics dashboard. Multi-tenant scoping on every queryset via
`ProjectScopedViewSetMixin`; pagination global; N+1 audited.

**Advanced** — notification signals (assignment add/remove, report approval),
`notify_due_milestones` management command, ReportLab PDFs (project summary,
monthly report), Kenya location reference API (47 counties, all 290
constituencies, 1,378 wards, generated A/B locations for uncurated wards).

**Progress engine (EVM per PMBOK)** — composite = Financial×30% +
Physical×50% + Time×20%; CPI = physical/financial; **SPI = EV/PV** where PV is
built from the phase baseline (each phase's allocated budget × the elapsed
fraction of its own window), falling back to `time_progress` when a project has
no phases or no budget; `health_status` from the two indices. All computed
properties — no migrations, no caching.

**Structured donor reporting (2026-07-22, complete — 3 commits)**
- [x] `Report`: activity type, optional `linked_phase` / `linked_milestone`,
  `amount_spent` + notes, beneficiary breakdown (reached/male/female/youth),
  impact / challenges / recommendations / next steps, `posted_at`. All
  optional or defaulted — pre-existing reports stay valid.
- [x] Spend is now approval-driven: `ProjectPhase.spent_budget` = writable
  `opening_spend` baseline + `reported_spend` from approved reports.
  Migration is a state-only rename (`db_column` unchanged), so no data moved.
- [x] `post_report` / `unpost_report` services, atomic and idempotent, keyed on
  `posted_at`; approving completes a linked milestone, un-approving reverts it
  only if that report completed it. New `/reports/{id}/unapprove/` endpoint.
- [x] Validation: cross-project links rejected, `amount_spent >= 0`, gender
  split and youth bounded by total reached, approved reports frozen.
- [x] `Project.reported_spend`, `.beneficiaries_reached`, `.cost_per_beneficiary`
  exposed read-only; `phases__reports` prefetched against N+1.
- [x] Flutter capture form (commit 2): Submit Report wizard extended to six
  steps — Details → Activity → Impact → GPS → Photos → Review. Activity takes
  the activity type, phase/milestone pickers, spend and reach breakdown;
  Impact takes the four narrative fields. Client-side gender-split check,
  inline warning when spend has no phase to post to, and link pickers that
  degrade when a project has no phases/milestones.
- [x] Offline drafts carry the structured payload — `report_drafts` schema v2
  via additive ALTER TABLEs, so drafts saved by the previous build survive.
- [x] Donor output (commit 3): `project_impact_summary` rolls approved reports
  into reach / spend / cost-per-beneficiary / activity breakdown / narratives,
  served as JSON (`/projects/{id}/impact-summary/`) and as a ReportLab PDF
  (`/projects/{id}/impact-report/`) from the same function.
- [x] Flutter: Report Detail shows the recorded results and impact narrative;
  Project Overview gained `ProjectImpactCard` (reach, cost per person, gender
  bar, activity rows) with an explicit empty state.
- [x] Legacy `spent_budget` write shim removed — the phase editor sends
  `opening_spend` and is labelled "Baseline spend".
- [x] `seed_demo` seeds one fully structured approved report via `post_report`,
  so the demo shows the whole chain (spend posts to the Drilling phase, its
  milestone completes, the impact card fills).
- [x] Impact PDF download button on the card (hidden from officers): bytes
  fetched through Dio with the JWT, then handed to the platform via a
  conditionally-imported saver — browser download on web, documents directory
  elsewhere. Verified by capturing the real download in Chrome and rendering
  the PDF to check its contents.
- [x] 27 new backend tests and 15 new widget tests across the three commits;
  **243 backend / 67 Flutter tests pass**. Commit 1 was verified invisible to
  the shipped app (demo figures byte-identical, old build still working);
  commit 3 deliberately moves them, because the seeded structured report now
  posts real spend and completes a milestone.
- [x] Submission robustness (2026-07-22, `d27c0f7`): the wizard's three-call
  submit (create → upload photos → submit) is now idempotent across retries —
  the report is created once and each photo uploaded once, so a dropped
  connection can't produce a duplicate report or re-post images. A resumed
  draft's evicted photo is skipped (with a count shown) instead of throwing an
  unhandled filesystem error mid-submit. Also fixed a latent infinite-rebuild
  loop in the photo thumbnail (`readAsBytes()` future now created once). +2
  widget tests (retry-idempotency, evicted-photo) → **79 Flutter tests**.
- [x] Edit an existing report (2026-07-22, `312925c`): `perform_update` now
  enforces the workflow edit matrix (approved frozen; submitted = manager/admin
  only; draft = author or manager/admin) instead of freezing every non-draft
  edit — aligning the code with business rule #3. The Submit Report wizard
  doubles as an editor (`editing:` arg): pre-filled, project fixed, PATCH via
  `updateReport` with explicit clears, existing photos shown as a count and new
  ones appended (≤5 total). Report Detail gained a status/role-gated Edit
  button. Create-mode "Save as Draft" now persists a **server-side** draft
  (offline → local fallback), so drafts are reachable to edit. `project_name`
  added read-only to `ReportSerializer`. +7 backend / +7 Flutter tests →
  **261 backend / 86 Flutter**.
- [x] Remove photos when editing (2026-07-22, `5901411`): the edit Photos step
  shows attached images as thumbnails with an ✕; removing one deletes it on
  save (via new `deleteImage`, retry-safe, before new uploads so the 5-image
  cap holds). `ReportImageViewSet.perform_destroy` refuses removal from an
  approved report. +2 backend / +1 Flutter tests → **263 backend / 87 Flutter**.
- [x] Impact-PDF access + content (2026-07-22, `d42d0a3`, `eadd103`): tests
  lock that all four roles download the impact PDF NGO-scoped (cross-NGO /
  unassigned → 404, the ProjectViewSet convention). `donor_impact_pdf` gained
  project status/dates, an EVM block (financial/physical/time/overall %, CPI,
  SPI, health) and a "Field photos" section (approved+posted images, scaled to
  fit, captioned) — additions only, existing sections untouched.
- [x] Donor-grade fields required on substantive submit (2026-07-22,
  `ba82975`): a report linking a phase/milestone must carry activity_type,
  amount_spent, `reached>0`, a gender split and all four narratives before it
  can be submitted (enforced in the **submit action**, not `validate()`, since
  the transition never runs the serializer). Drafts and unlinked reports keep
  the light rules; seed bypasses submit, so no progress figure moved. Flutter
  mirrors it (asterisks + Submit disabled until filled; Save-as-Draft never
  blocked). +4 backend / +1 Flutter tests → **274 backend / 88 Flutter**.

**Reporting trend series (2026-07-22, `5246b7e`)**
- [x] `GET /analytics/reports-series/` — a contiguous run of months (`months`
  1–24, default 6), oldest first, zero-filled. Buckets by `date_submitted`;
  approved count, reach and spend come only from approved, posted reports.
- [x] Role scoping delegated to `AnalyticsDashboardView` so the series and the
  dashboard can never disagree; response shapes declared as read-only
  serializers for drf-spectacular. 11 new backend tests.
- [x] Flutter analytics dashboard wired to it: the status-count "Reports
  Overview" bars are replaced by a "Reporting Trend (Last 6 Months)" card —
  grouped submitted/approved bars per month, oldest left, legend, tooltips and
  an empty state, on its own `FutureBuilder`. Status totals stay in the summary
  bar. Verified in Chrome across a full six-month spread. 4 new widget tests.
- [x] `seed_demo` back-dates ~14 plain reports across the last five months so
  the trend spans months instead of one bar; they carry no phase/milestone,
  reach or spend, so posting the approved ones moves no EVM or impact figure.

**Gaps vs the CLAUDE.md spec** (all deliberate, see DECISIONS.md)
- No `services.py` layer — logic sits in views/serializers.
- Python 3.9 / Django 4.2 LTS instead of 3.12 / 5.x.
- Older CRUD endpoints return raw DRF payloads; only the five newer endpoints
  use the `{status, data, message}` envelope (retrofitting breaks the client).
- Milestone auto-overdue has no standalone cron command.

---

## Mobile (Flutter)

**Core** — Dio client with JWT interceptor (attach, 401 → refresh once →
retry, auth-failure callback), `SecureTokenStore`, Provider state, GoRouter
with role-based redirect guards + `AppShell` bottom nav (5 tabs; 3 for donor),
design tokens (`AppColors`/`AppTextStyles`/`AppThemeData`), shared widget
library, `core/feedback.dart` snackbars, shimmer loading on every list screen,
inline validation on blur, sqflite offline report drafts (in-memory on web).

**All 17 screens** — splash, login, register, forgot password, dashboard
(role-aware), projects list, project detail (4 tabs + EVM cards + phase
management), create/edit project, submit report (4-step wizard, GPS, photos),
reports list, report detail, beneficiaries list, register beneficiary (Kenya
5-level cascading picker), notifications, profile, user management (list,
create, **edit**, activate/deactivate), NGO management, analytics (fl_chart).

**Visual language** — eCitizen / Kenya-government: green #006633 + gold
#CC9900, Inter, squared corners, `OfficialCard` with gold left rule, flag
ribbon, table-style lists.

**EVM UI** — `ProjectProgressCard` (composite ring + three dimension bars with
detail lines), `ProjectHealthCard` (rating badge, CPI/SPI with plain-language
readings and an "Earned X% of budgeted work vs Y% planned" footnote),
`PhaseBudgetTable`, `HealthDot`, `PhaseManagementScreen`, milestone weights,
and `EvmProgressTrack` on the project-list **and dashboard** rows — composite
fill with the physical (earned value) band over it and a tick at planned
value, keyed by a shared `EvmTrackLegend`. The dashboard passes the project's
status accent so those rows stay red/amber/green (its legend then uses neutral
swatches, since the key can only speak to shading there). Physical is drawn as its own band
because SPI is EV/PV: a tick read against the *composite* fill would not be a
schedule reading.

**Gap** — flat repository pattern rather than data/domain/presentation layers
(D-006).

---

## Verification state

- Backend **257 tests** pass on SQLite test settings.
- OpenAPI schema is clean: `spectacular --validate` → **0 errors / 0 warnings**
  (was 12 / 21); `/api/v1/schema/` and `/api/v1/docs/` both serve 200.
- Backend **263 tests** and Flutter **87 tests** pass; `flutter analyze` 0
  issues; `flutter build web` OK.
- User edit flow verified live in Chrome (tap card → pre-filled sheet → PATCH
  persists → list refreshes); demo data restored afterward.
- Live 4-role browser pass: every screen renders with zero console/API errors.
- `docs/screenshots/` regenerated 2026-07-21 against the current build and the
  reseeded demo data (15 app frames + 2 Django verify-email pages); every frame
  checked by eye, and the EVM tracks additionally at 4× magnification.
- Demo data shows deliberate health variety: Girls Education healthy
  (SPI 1.02), Clean Water and Food Security critical, Community Clinic
  not_started.

---

## Backlog

- Empty — every logged post-phase item is complete (structured donor
  reporting, reporting-trend chart, Swagger cleanup, user edit, Kenya ward
  keying). Further work would be new scope.
