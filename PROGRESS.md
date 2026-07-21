# PROGRESS — Smart NGO M&E Application

**Current state snapshot.** Dated per-session entries live in `git log`.

Last updated: 2026-07-21 · `main` @ `f438933`
**Backend 216 tests · Flutter 50 tests · `flutter analyze` 0 issues · Swagger 0/0**

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
`PhaseBudgetTable`, `HealthDot`, `PhaseManagementScreen`, milestone weights.

**Gap** — flat repository pattern rather than data/domain/presentation layers
(D-006).

---

## Verification state

- Backend **216 tests** pass on SQLite test settings.
- Flutter **50 tests** pass; `flutter analyze` 0 issues; `flutter build web` OK.
- Live 4-role browser pass: every screen renders with zero console/API errors.
- `docs/screenshots/` regenerated 2026-07-21 against the current build and the
  reseeded demo data (15 app frames + 2 Django verify-email pages).
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
- Surface `plannedValueProgress` beyond the health card (e.g. a PV marker on
  project-list progress bars).
