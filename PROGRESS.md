# PROGRESS — Smart NGO M&E Application

**Current state snapshot.** Dated per-session entries live in `git log`.

Last updated: 2026-07-22 · `main` @ local commit (unpushed)
**Backend 232 tests · Flutter 55 tests · `flutter analyze` 0 issues · Swagger 0/0**

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

**Structured donor reporting (2026-07-22, commit 1 of 3 — backend only)**
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
- [x] 16 new tests (`apps/reports/tests/test_structured_reporting.py`);
  **232 backend tests pass**. Demo figures verified byte-identical before and
  after (no report carries spend yet), and the shipped Flutter build still
  works unchanged against the new API.

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
5-level cascading picker), notifications, profile, user management, NGO
management, analytics (fl_chart).

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

- Backend **232 tests** pass on SQLite test settings.
- Flutter **55 tests** pass; `flutter analyze` 0 issues; `flutter build web` OK.
- Live 4-role browser pass: every screen renders with zero console/API errors.
- `docs/screenshots/` regenerated 2026-07-21 against the current build and the
  reseeded demo data (15 app frames + 2 Django verify-email pages); every frame
  checked by eye, and the EVM tracks additionally at 4× magnification.
- Demo data shows deliberate health variety: Girls Education healthy
  (SPI 1.02), Clean Water and Food Security critical, Community Clinic
  not_started.

---

## Backlog

- Monthly report series endpoint → real 6-month trend chart (today the bar
  chart shows counts by status).
- Donor PDF download button (PDFs exist, no UI entry point).
- User detail/edit screen.
- Key Kenya ward/location dicts by (constituency, ward) to fix same-named
  wards sharing one location list.
