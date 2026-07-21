# PROGRESS.md — Smart NGO M&E Application
### Last updated: 2026-07-21

---

## True PV-based SPI (2026-07-21) ✅

SPI was `physical / time` — a straight-line plan assumption that misreads
any front- or back-loaded project. Now `EV / PV` per PMBOK, with PV read
off the phase baseline.

- [x] Backend: `Project.planned_value_progress` — each phase contributes its
  allocated budget × the elapsed fraction of that phase's own window
  (module-level `_elapsed_fraction`, zero-length windows safe), as a % of
  budget, capped at 100
- [x] Backend: `schedule_performance_index` = physical / PV (budget cancels
  since both are % of the same budget); `None` when PV is 0, i.e. before
  any work was *scheduled* to start — no longer tied to the calendar
- [x] Documented fallback: no phase plan or non-positive budget → PV degrades
  to `time_progress` (the entire old model becomes just the fallback)
- [x] `planned_value_progress` exposed read-only on `ProjectSerializer`;
  no migration needed (all computed properties)
- [x] 7 new tests in `test_progress_evm.py` (front-loaded baseline, partial
  phase, over-allocation cap, zero-length phase, linear fallback, PV=0 →
  SPI None, API exposure); **215 backend tests pass** (was 208)
- [x] Seed check: reseeded and printed PV/SPI/health per project — demo still
  shows variety (Girls Education healthy, SPI 1.11 → 1.02; Clean Water and
  Food Security critical; Clinic not_started). No seed retune needed.
- [x] Flutter: `ProjectHealthCard` SPI readings reworded from schedule
  language to "ahead of / behind planned work"; analyze 0, 47/47 tests
- [x] Flutter: `Project.plannedValueProgress` parsed from the API (0 when the
  key is absent, so pre-PV payloads still parse) and surfaced as a footnote
  under the SPI row — "Earned 20.0% of budgeted work vs 19.7% planned", one
  decimal so the figure explains the index; 3 new tests, **50 Flutter tests**
- [x] Verified live in Chrome at 430×932: Girls Education SPI 1.02 healthy,
  Food Security SPI 0.20 critical (49% planned vs 34% calendar — the
  front-loaded case the fix exists for), zero console/API errors

---

## Weighted Composite Progress — EVM (2026-07-18) ✅

Project progress upgraded from "% of timeline elapsed" to a PMBOK-style
Earned Value composite (commit `9e38da6`):
**Progress = Financial × 30% + Physical × 50% + Time × 20%.**

- [x] Backend: `ProjectPhase` model (type, allocated/spent budget, dates, status) + nested `/projects/{id}/phases/` CRUD (reads: any authenticated NGO member; writes: manager/admin); `Milestone.weight` (1–10, serializer-bounded)
- [x] Backend: computed on `Project` — financial (phase spend / budget), physical (completed milestone weight share), time (calendar elapsed), composite, CPI, SPI, `health_status` (healthy ≥0.95 / at_risk ≥0.8 / critical); all exposed read-only on `ProjectSerializer`, `phases`+`milestones` prefetched against N+1
- [x] Migration `0002_milestone_weight_projectphase`; `seed_demo` extended — 14 phases + weighted milestones give one healthy, two critical, one not-started demo project
- [x] New `test_progress_evm.py`; **208 backend tests pass** (accidental `test_auth.py` regression from the interrupted session reverted — API uses first_name/last_name)
- [x] Flutter: `ProjectProgressCard` (composite ring + 3 dimension bars with detail lines), `ProjectHealthCard` (CPI/SPI + plain-language readings + rating badge), `PhaseBudgetTable` (official table, TOTAL row, Manage Phases action), `HealthDot`
- [x] Flutter: `PhaseManagementScreen` (phase CRUD, add/edit bottom sheet, "progress recalculated" feedback); milestone weight dropdown in Add Milestone sheet + weight shown on milestone cards
- [x] Flutter: projects list + dashboard rows switched to server composite (health dots; list rows show "F/P/T" breakdown); project-detail header badge now "N% complete"
- [x] Verified: analyze 0, **47/47 Flutter tests**, live browser pass (dashboard, project register, detail cards, phase management, milestones) with zero console/API errors

---

## eCitizen UI Review Fixes (2026-07-17) ✅

Peterson's round-2 review, all resolved (commit `2a7252c`, pushed):

- [x] Dashboard stats: 2×2 grid → compact horizontal 4-box colored strip (flush surfaces, separators; 10px labels make 4-across fit)
- [x] Recent Projects rows: link-blue names + meta line (end date, KES budget)
- [x] AppBar subtitles completed: beneficiaries count + analytics "Smart NGO M&E — ‹NGO›" (projects/reports already had theirs)
- [x] Verified: analyze 0, 47/47 tests, live dashboard capture + subtitle crops; docs screenshots refreshed
- [x] Final re-verification: screenshot set recaptured live, byte-identical — repo, docs, and demo environment confirmed in sync; **demo-ready**

---

## eCitizen Official UI Redesign (2026-07-16) ✅

Full design-language swap to Kenya-government/eCitizen style, in two passes
(structure `13a11a2`, dashboard richness `74fb017`):

- [x] Palette swapped at the foundation: Kenya green #006633 + gold #CC9900, blue-tinted #F0F2F5 background; legacy AppColors names kept as aliases so untouched screens repainted automatically
- [x] Theme: Inter-only typography, green AppBars with 2px gold rule, squared buttons/inputs (radius 2), bordered cards (radius 4)
- [x] New shared widgets: OfficialCard (gold left rule + uppercase title + gradientHeader variant), FlagRibbon, InfoRow; StatusBadge → bordered official style
- [x] Dashboard: official government header (flag ribbon, logo box, user-info bar, gold accent bars), gradient welcome banner, colored 2×2 statistics boxes, gradient service tiles, table-style project rows, timeline activity feed
- [x] Login: government identity header + SYSTEM LOGIN card + institutional footer (all keys/logic kept)
- [x] Lists as official tables: projects (NAME|STATUS|PROGRESS), reports (TITLE|TYPE|STATUS), beneficiaries (NAME|AGE|STATUS) — green column headers, alternating rows, link-blue titles
- [x] Profile info tables, notifications log rows, analytics summary bar + OfficialCard charts, gold-ruled bottom nav
- [x] Fixes en route: FlagRibbon zero-height collapse (childless ColoredBox needs stretch), Container color+decoration assert, ShimmerCard adaptive line count
- [x] Verified: analyze 0, 47/47 tests, all 4 roles live, docs screenshots refreshed

---

## Sub-Location Dropdown Removed (2026-07-16) ✅

Final picker shape per Peterson (commit `070ad45`): 5 dropdown levels + free text —
Country (locked) → County → Constituency → Ward → Location, then a free-text
"Village / Sub-location" field:

- [x] Sub-location dropdown, state, loader, and emit key removed from `KenyaLocationPicker` (Flutter-only change)
- [x] Backend intentionally untouched: `sub_location` field, `?location=` API level, and reference data remain (new records leave it empty)
- [x] Verified: analyze 0, 47/47 tests, live E2E (Baringo chain + typed village, submitted, card shows "Location · Ward · Constituency"), register screenshot retaken
- [x] Full docs screenshot set refreshed (`8a210c6`) — repo, docs, and demo environment in sync

---

## Kenya Ward Data Complete (2026-07-16) ✅

All 290 constituencies now have ward data (commit `eca21ca`):

- [x] `CONSTITUENCY_WARDS` covers every constituency — 1,378 ward entries, no duplicate keys, zero gaps (verified programmatically)
- [x] Merge corrections: Lungalunga→Lunga Lunga, Mt Elgon→Mt. Elgon, "West Pokot"→Kapenguria, skipped non-existent "Mau Narok"/"Murang'a South" (real Kangema wards added), added missing Busia county (7 constituencies), fixed Ndia
- [x] Locations for uncurated wards generated as "‹ward› A/B" via a setdefault loop (curated lists stay authoritative); sub-locations degrade to skip
- [x] New integrity tests: every constituency has wards, every ward has locations — 195 backend tests pass
- [x] Verified: API spot-checks across 6 counties + live browser cascade through Bomet (previously "No ward data")
- [x] Docs screenshots refreshed (`694e7b0`); all pushed — repo, docs, and demo environment in sync
- Known limitation: dicts keyed by bare ward name, so same-named wards share location lists (future: key by constituency+ward)

---

## Kenya Location Hierarchy (2026-07-16) ✅

eCitizen-style cascading location capture for beneficiaries, built in two passes
(picker v1 `78e98d0`, 5-level hierarchy `5486335`, screenshots `eb43b69`):

- [x] Reference data: all 47 counties, complete real constituency list (290), ward lists for demo + major counties, locations + sub-locations for a representative ward subset
- [x] Integrity tests pin the chain (every ward key a real ward, every location key a real location); levels without data degrade to an empty list, never an error
- [x] `GET /api/v1/locations/kenya/` (public): ?counties / ?county / ?constituency / ?ward / ?location, sorted counties
- [x] Beneficiary model: `location` CharField replaced by country/county/constituency/ward/location/sub_location/village + `full_location` property (migrations 0002–0003); serializer + CSV export updated; seed data carries full chains
- [x] Flutter `KenyaLocationPicker` (shared widget): locked Kenya field, 5 cascading dropdowns with shimmer/disabled/skip states, village field; Register Beneficiary rebuilt into section cards (Personal / Location / Project)
- [x] Beneficiary cards show "Sub-Location · Location · Ward" (degrading gracefully)
- [x] Verified: backend 193 tests, Flutter 47 tests, analyze 0; live full-depth registration E2E + no-data branch; docs set now 14 screenshots (added app-register-beneficiary.png)

---

## Premium Dashboard Redesign v2 (2026-07-16) ✅

Full rewrite of `dashboard_screen.dart` to fintech-grade spec (commit `0c1a30b`, screenshots `acc7400`):

- [x] Pinned (non-scrolling) gradient header; content sheet scrolls under its 28px rounded corners (LayoutBuilder + OverflowBox + translate)
- [x] 3-stop deep-forest gradient + faint dot-grid texture overlay (CustomPaint)
- [x] Full name 26px, glassy role pill with amber role icon, amber 18px bell badge with green ring
- [x] 52px amber-gradient avatar with glow → taps to Profile
- [x] Stats strip: bordered glass panel, 24px amber numbers, shimmer while loading
- [x] Quick actions: chrome-less 56px icon tiles (green gradient primary / amber tint secondary)
- [x] Project cards: fading 5px accent bar, Progress % row, rounded LinearProgressIndicator, formatted date + budget chips, shimmer + role-aware empty state
- [x] Activity feed: single grouped card, tinted icon circles, title + message + timestamp, indented dividers
- [x] SectionHeader bumped to 17px bold app-wide; dashboard has no FAB (already true)
- [x] Verified: analyze 0, 44/44 tests, all 4 roles live, pinned scroll + pull-to-refresh (CDP touch), 360×740 no overflow

---

## UI Review Fixes (2026-07-16) ✅

Seven-item review from Peterson, all resolved (commit `ec2aaba`, screenshots `b80b920`):

- [x] Quick-action chip overflow: height 90→96px (icon square + two wrapped label lines)
- [x] Project accent bars: new `StatusBadge.accentFor()` vivid palette (active=green, planning=amber, on_hold=red, completed=blue, cancelled=grey) on dashboard + projects list
- [x] Beneficiary cards show project name: `project_name` added to `BeneficiarySerializer` (read-only, no N+1) + Flutter model/card
- [x] Bell badge: 16px stadium, 10px bold, caps at "9+"
- [x] Submit Report dropdown: loading spinner added (auto-fetch + error/retry already existed)
- [x] Bottom-nav active dot: 4→6px
- [x] Profile Sign Out: verified already present and visible — no change needed
- [x] Verified: backend 180 tests, Flutter 44 tests, analyze 0, live browser check; docs screenshots retaken

---

## UI Consistency Pass (2026-07-14) ✅

Final pre-demo polish — one visual system across all 17 screens:

- [x] Design tokens: `AppThemeData` (gradient, shadows, decorations, input decoration) + `AppTextStyles` (typography roles)
- [x] Buttons unified via theme: 50px / 12px radius / Space Grotesk labels (filled, outlined, text)
- [x] Success + error snackbar helpers (`core/feedback.dart`) used at every call site
- [x] Page transitions: fade (tabs) + slide (pushed routes) in GoRouter
- [x] Shimmer loading on all list screens (incl. notifications, analytics)
- [x] Analytics: KPI icon circles + amber numbers; demographics amber=female / green=male
- [x] Verified: analyze 0 issues, 44/44 tests, release web build OK

---

## Overall Status

| Phase | Title | Status |
|-------|-------|--------|
| Phase 1 | Backend Foundation | ✅ Complete |
| Phase 2 | Core API | ✅ Complete — all endpoints implemented |
| Phase 3 | Advanced Backend Features | ✅ Complete |
| Phase 4 | Flutter App | ✅ Complete — all 17 screens implemented, GoRouter wired, analyze clean |
| Phase 5 | Quality Assurance & Polish | ✅ Complete |

---

## Phase 1: Backend Foundation ✅

All steps complete. Verified working.

- [x] Django project with split settings (base / dev / prod / ci / test_sqlite)
- [x] All dependencies installed (requirements.txt — flat file, not split; see DECISIONS.md)
- [x] CustomUser model: email login, role enum (admin/manager/officer/donor), ngo FK, is_active soft-delete
- [x] All 11 database tables modelled across 8 Django apps
- [x] All migrations generated and applied
- [x] simplejwt configured: 15 min access / 7 day refresh, rotation, blacklisting
- [x] BCryptSHA256PasswordHasher configured with PBKDF2 fallback
- [x] DRF throttling: 20/min anon, 100/min user
- [x] Custom permission classes: IsSystemAdmin, IsProjectManager, IsFieldOfficer, IsDonor, IsSameNGO, ReadOnly
- [x] Auth endpoints: register, login, logout, token/refresh, password-reset, password-reset/confirm
- [x] Password reset: secrets.token_urlsafe, SHA-256 hash stored, 1hr TTL, single-use
- [x] drf-spectacular configured at /api/v1/docs/ (0 schema warnings)
- [x] Custom exception handler at config/exceptions.py (returns {error, code} envelope)
- [x] Tests for accounts app: 119 total across all apps; accounts subset covers auth, password reset, permissions, security boundaries

**Gap vs CLAUDE.md spec:**
- `GET /auth/me/` endpoint is missing from accounts/urls.py
- `backend/core/` directory (responses.py, pagination.py, utils.py) was not created — exception handler lives at `config/exceptions.py` instead
- `requirements/` split (base/dev/prod) not done — flat `requirements.txt` used
- No `services.py` in any app — logic lives in views (see DECISIONS.md)
- Python 3.9.6 used, spec says 3.12 (see DECISIONS.md)
- Django 4.2.30 used, spec says 5.x (see DECISIONS.md)

---

## Phase 2: Core API 🟡

All primary CRUD endpoints implemented. Five secondary endpoints missing.

- [x] NGO ViewSet (admin only), serializer, registered on router
- [x] Project ViewSet: CRUD, NGO-scoped queryset, role permissions, budget/date validation
- [x] ProjectAssignment sub-resource at /projects/<pk>/assignments/ (list, create, delete)
- [x] Beneficiary ViewSet: CRUD, computed age via SerializerMethodField, soft-delete, project scoping
- [x] Indicator ViewSet: CRUD, computed progress_percentage, manager/admin write
- [x] Milestone ViewSet: CRUD, auto-overdue in to_representation(), manager/admin write
- [x] Report ViewSet: CRUD, draft→submitted→approved workflow, officer_id preserved
- [x] ReportImage sub-resource: multipart upload, MIME validation, 5 MB limit, 5 per report max
- [x] Notification ViewSet: list (own only), PATCH mark-read, DELETE
- [x] Multi-tenant filtering on every queryset (ngo-scoped)
- [x] PageNumberPagination globally configured (PAGE_SIZE=20)
- [x] ProjectScopedViewSetMixin shared mixin in apps/common/mixins.py

**Completed 2026-07-08:**
- [x] `POST /notifications/mark-all-read/` — bulk mark-read @action added to NotificationViewSet
- [x] `GET /beneficiaries/export/` — CSV export @action added, role/NGO scoped
- [x] `/api/v1/users/` — UserManagementViewSet (admin only): list, create, PATCH toggle-active
- [x] `/api/v1/analytics/dashboard/` — role-filtered stats (projects by status, beneficiaries, reports, notifications)
- [x] `GET /api/v1/auth/me/` — current user profile endpoint
- [x] `backend/core/` created: responses.py (SuccessResponse), pagination.py, utils.py
- [x] `requirements/` split into base.txt / development.txt / production.txt
- [x] Standard success envelope `{status, data, message}` used on all 5 new endpoints

**Note:** Existing CRUD endpoints still return raw DRF data (no wrapper). Retrofitting would break the Flutter client.

---

## Phase 3: Advanced Backend Features ✅

Signals, PDF, notifications, and management commands all implemented.

- [x] Django signals in notifications/signals.py (connected via NotificationsConfig.ready()):
  - post_save ProjectAssignment → notify assigned user
  - post_delete ProjectAssignment → notify removed officer
  - pre_save/post_save Report → notify officer on status change to approved (no dup)
- [x] Notification service layer: notify() and notify_users() in notifications/services.py
- [x] Management command: notify_due_milestones (--days=3, marks overdue, notifies team)
- [x] PDF generation via ReportLab 4.5:
  - project_summary_pdf(): project info, budget, indicators, milestones
  - monthly_report_pdf(): approved reports for given year/month
  - Exposed as @action on ProjectViewSet: GET /projects/{id}/summary-pdf/ and /monthly-report/
- [x] All signal and PDF logic covered by tests (19 tests in projects/tests/test_pdf_api.py, test_notify_command.py; notifications/tests/test_signals.py)

**Missing vs CLAUDE.md spec:**
- [ ] Beneficiary CSV export management command / endpoint (Phase 2 gap carried forward)
- [ ] Milestone auto-overdue management command as a standalone command (auto-overdue IS implemented in the serializer's to_representation; a standalone cron command is not)

---

## Phase 4: Flutter App 🟡

All 17 screens implemented. Architecture lighter than CLAUDE.md spec (flat repos, no data/domain/presentation layers) but fully functional.

**Structure:** Feature-based (`lib/features/{auth,dashboard,projects,reports,beneficiaries,notifications,analytics,users,ngos,splash}/`).

### Implemented (complete as of 2026-07-08)
- [x] Dio client with JWT interceptor (attach token, 401→refresh once→retry, onAuthFailure callback)
- [x] SecureTokenStore wrapper (flutter_secure_storage)
- [x] Provider state management (AuthProvider, NotificationsProvider)
- [x] Design system: AppColors (Forest Green/Amber/Sage/Cream), Space Grotesk + Inter via google_fonts, 18px card radius, 10px input radius, 50px button height
- [x] Material 3 theme fully configured in core/theme.dart
- [x] **GoRouter** with role-based redirect guards, ShellRoute for nav shell
- [x] **AppShell** (GoRouter ShellRoute) with NavigationBar bottom nav (role-aware: 5 tabs for admin/manager/officer, 3 for donor)
- [x] **Splash screen** — fade+scale animation, waits for auth bootstrap
- [x] Login screen (split-panel: green header + warm-cream form card, forgot password link)
- [x] Register screen
- [x] Forgot Password screen (email → confirmation state)
- [x] Profile screen (green header, role badge, sign-out confirm, analytics/admin nav links)
- [x] Dashboard screen (greeting card, 3-column KPI tiles, notifications bell)
- [x] Projects list (AppBar search, status filter chips, shimmer loading, rich project cards)
- [x] **Create Project screen** (3-step form: Details → Budget → Timeline; date pickers, status chips)
- [x] Project detail (4 tabs: Overview, Milestones, Team, KPIs; FAB → submit report)
- [x] Submit Report screen (GPS capture, multi-image picker, save draft / submit)
- [x] Reports list (status filter chips, shimmer loading, tap-to-detail navigation)
- [x] **Report Detail screen** (GPS display, photo gallery, approve button for manager/admin)
- [x] Beneficiary list (AppBar search, shimmer loading, card layout, role-aware empty state)
- [x] Register Beneficiary (DOB date picker, gender, project selector)
- [x] Notifications screen (icon containers, unread dot, relative timestamps, swipe-to-delete)
- [x] **Analytics Dashboard** (PieChart projects by status, BarChart reports, 3 KPI tiles — fl_chart)
- [x] **User Management** (admin only: list with shimmer, activate/deactivate toggle)
- [x] **NGO Management** (admin only: list with shimmer, NGO cards)
- [x] `/auth/me/` refresh on AuthProvider bootstrap (fresh user data after restore)
- [x] **Loading shimmers** on all list screens
- [x] 31 widget and unit tests; `flutter analyze` — 0 issues

### Remaining gaps vs CLAUDE.md spec
- [x] **sqflite** offline draft storage — done 2026-07-13: local-only report drafts
  (save/resume/submit-deletes, Reports list "Local draft" section, in-memory
  fallback on web); see DECISIONS.md D-010; 8 new tests
- [x] **Inline validation on blur** — done 2026-07-13: shared `BlurValidatedTextField`
  widget (validates on focus loss, then re-validates per keystroke so errors clear);
  applied to all 12 validated fields across the 6 form screens; 3 widget tests added
- [ ] **Clean Architecture layers** — flat repo pattern (see DECISIONS.md D-006)

---

## Phase 5: Quality Assurance & Polish ✅

Complete as of 2026-07-08.

- [x] Full backend test suite: **155 passed, 0 failed**
- [x] `flutter analyze`: **0 issues**
- [x] `flutter test`: **31/31 passed**
- [x] Security test suite (`test_security_boundaries.py`): cross-role denials, token expiry, tampered token, blacklisted refresh, rate limiting, multi-tenant isolation
- [x] N+1 audit: all ViewSet querysets use `select_related`/`prefetch_related`; fixed notifications missing `select_related("user")`
- [x] README.md updated: test counts, all API endpoints, tech stack, 17 screens listed
- [x] No debug print statements (confirmed by grep)
- [x] Final HANDOVER.md written

---

## ALL 5 PHASES COMPLETE + Email Verification

**Project is assessment-ready.**

Backend: 172 tests · 30+ API endpoints · Swagger UI at /api/v1/docs/
Mobile: 31 tests · 17 screens · flutter analyze clean · GoRouter + fl_chart + shimmer

---

## Email Verification & Registration Overhaul (2026-07-08)

- [x] `EmailVerificationToken` model + migration (`email_verification_tokens` table)
- [x] Registration sets `is_active=False`; sends verification email via console backend in dev
- [x] `GET /api/v1/auth/verify-email/?token=` — activates account, single-use
- [x] `POST /api/v1/auth/resend-verification/` — re-sends email, always 200
- [x] Login blocked for unverified users: code `EMAIL_NOT_VERIFIED`, 401
- [x] Admin role blocked on public register; manager now allowed to self-register
- [x] `GET /api/v1/ngos/public/` — unauthenticated NGO list for registration dropdown
- [x] Flutter register screen: confirm password, eye toggles, NGO dropdown, role helpers, success screen
- [x] Flutter login screen: resend button appears on EMAIL_NOT_VERIFIED error
- [x] **Backend: 172 tests pass. Flutter: 31 tests, 0 analyze issues.**

---

## Inline Validation on Blur (2026-07-13)

- [x] `lib/shared/widgets/blur_validated_text_field.dart` — TextFormField wrapper
  with internal FocusNode: validates on focus loss, then `onUserInteraction`
  re-validation so the error clears as the user types a fix
- [x] Applied to all validated text fields: login (email, password), register
  (first name, email, password, confirm), forgot password (email), create project
  (name, budget), register beneficiary (name, project ID), submit report (title)
- [x] 3 widget tests in `test/shared/blur_validated_text_field_test.dart`
- [x] **Flutter: 34 tests pass, `flutter analyze` 0 issues.**

---

## Complete UI Overhaul (2026-07-13)

All 17+ screens redesigned to the design-system spec (forest green / amber /
warm cream, Space Grotesk + Inter, 12px cards at elevation 2, status pills on
tint backgrounds).

- [x] Shared widget library in `lib/shared/widgets/`: StatusBadge,
  ProjectProgressBar (animated gradient), KpiCard, SectionHeader, EmptyState,
  ShimmerCard/ShimmerList, InfoChip
- [x] AppColors extended with the status tint palette (success/warning/
  danger/info/neutral on soft tints); FABs now primary green; nav bar 64px
- [x] Dashboard: green greeting header (role pill, amber avatar, bell badge),
  role-aware KPI row from /analytics/dashboard/, 2×2 quick actions grid,
  Recent Projects mini-cards with progress bars, Recent Activity feed with
  colored dots
- [x] Submit Report rebuilt as a 4-step wizard (Details → Location → Photos →
  Review) with project selector, GPS accuracy display, 3×N photo grid capped
  at 5, and a review summary; drafts resume into the wizard
- [x] Create/Edit Project: steps now Details → Budget & Timeline → Team
  (officer multi-select with removable chips); edit mode reuses the form
- [x] Project detail: header badges (status/budget/% elapsed), 2×2 info grid
  with beneficiary count, tab-aware FAB, Add Milestone / Add Indicator /
  Assign Officer bottom sheets, remove-member with confirm
- [x] Reports list: count subtitle, "On This Device" drafts section with
  swipe-to-delete, officer name chips; Report detail: View on Maps
  (url_launcher), full-screen photo viewer, approve confirmation dialog
- [x] Beneficiaries: Total/Female/Male stats row, gender filter chips,
  gender-colored avatars, active/inactive badges; register form with
  segmented gender control, live computed age, project dropdown
- [x] Notifications: Today/This Week/Earlier grouping, type-colored left
  borders, amber-tinted unread cards, Mark-all-read
- [x] Profile: green header (amber initials avatar, role pill, NGO name),
  account info card, settings section; Analytics: 4 KPI tiles + third chart
  (beneficiary demographics pie)
- [x] Admin screens: user stats row + role filters + create-user sheet +
  active switches; NGO count header + initials avatars + register-NGO sheet
- [x] Backend: managers can now list users (read-only, own NGO) so they can
  build project teams — 4 new permission tests
- [x] seed_demo rewritten: 3 NGOs, Kenyan project/beneficiary data, milestone
  mix incl. overdue, manager notifications for the activity feed
- [x] **Backend: 176 tests pass. Flutter: 42 tests pass, analyze clean,
  web build OK, API verified end-to-end against seeded data.**

---

## sqflite Offline Report Drafts (2026-07-13)

- [x] `lib/features/reports/models/report_draft.dart` — ReportDraft (form fields,
  GPS, photo paths as JSON, updated_at) with sqflite row mapping
- [x] `lib/features/reports/draft_store.dart` — `DraftStore` interface;
  `SqfliteDraftStore` (lazy-opened `smartngo_drafts.db`, schema v1);
  `InMemoryDraftStore` for web + widget tests
- [x] Submit Report: "Save draft" now saves locally (works offline); resuming a
  draft pre-fills the form; successful submit deletes the originating draft
- [x] Reports list: "On this device" section under All/Drafts filters with amber
  "Local draft" badge, tap-to-resume, delete icon; local drafts stay visible
  even when the server list fails (offline)
- [x] Design decision D-010 in DECISIONS.md (local-only drafts; web in-memory fallback)
- [x] 4 store tests against real SQLite (`sqflite_common_ffi`) + 3 new widget tests
- [x] **Flutter: 41 tests pass, `flutter analyze` 0 issues, `flutter build web` OK.**
