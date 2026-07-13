# PROGRESS.md — Smart NGO M&E Application
### Last updated: 2026-07-13

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
