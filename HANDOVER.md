# Session Handover — 2026-07-16 | UI Review Fixes

---

## UI review fixes (2026-07-16, from Peterson's 7-item review)

- **Quick-action chip overflow**: chip height 90→96px — the 40px icon square
  plus two 11px label lines overflowed by ~4px on wrapping labels ("Add
  Beneficiary"). maxLines/ellipsis were already present.
- **Project accent bars**: new `StatusBadge.accentFor()` — vivid bar palette
  (active=primary green, planning=amber, on_hold=red, completed=#1D4ED8
  blue, else grey) used by dashboard mini-cards AND the projects list. The
  bars existed but used the badge tint palette, which rendered muddy at 4px
  (on_hold was an indistinct grey).
- **Beneficiary cards show project**: backend `BeneficiarySerializer` gained
  read-only `project_name` (source=project.project_name; queryset already
  select_related("project")); Flutter model + card show it grey 11px under
  the location. NOTE: needed a backend restart — the dev server runs
  --noreload, so serializer changes don't hot-apply.
- **Bell badge**: 16px stadium, 10px bold, caps at "9+", unchanged -4/-4
  offset; only rendered when unread > 0 (as before).
- **Submit Report project dropdown**: already auto-loaded on init with
  error+retry; added the missing loading state (16px spinner + "Loading
  projects…" in the field while fetching).
- **Bottom-nav active dot**: 4→6px under the active icon.
- **No change needed**: Profile "Sign Out" already exists as the last card
  (red text, logout icon, confirm dialog) and is visible without scrolling
  at 430×932 — screenshot `docs/screenshots/app-profile.png` shows it.
- Verified: backend 180 tests, Flutter 44 tests, analyze 0; live in-browser
  check of officer/manager dashboards, beneficiaries list (project names
  visible), and the populated submit-report dropdown. Commit not pushed —
  Peterson's checklist ended at HANDOVER; push when ready.

---

## App-wide UI consistency pass (2026-07-14, final pre-demo polish)

Full-app pass so every screen shares one visual system. Work spanned two
sessions (the first was interrupted before verification/commit; this one
completed, verified, and committed it).

- **Design tokens** (`mobile/lib/core/constants/`): new `AppThemeData`
  (header gradient, card/header shadows, card + overlap-sheet decorations,
  uniform `inputDecoration(label, icon)`) and `AppTextStyles` (screenTitle,
  greeting, sectionTitle, cardTitle, body, caption, label, capsLabel,
  kpiNumber, buttonText — built with google_fonts, not fontFamily strings).
- **Theme** (`core/theme.dart`): filled/outlined buttons unified at 50px
  height, 12px radius, Space Grotesk labels; snackbars use primary green.
- **Feedback** (`core/feedback.dart`): `showSuccessSnackBar` (green, amber
  check) and `showErrorSnackBar` (red, alert icon). **Every** failure/
  validation snackbar across login, register, forgot-password, NGO/user
  management, project detail/create, submit report, report detail, and
  register beneficiary now routes through these — errors no longer render
  on the success-green theme background.
- **Router** (`core/router.dart`): 150ms fade for bottom-nav tab switches,
  200ms slide-in for pushed routes (analytics, users, ngos, project new,
  report detail).
- **Screens**: splash (gradient + fade/scale), login/register (green top +
  white 28px-radius overlap card), forgot password (icon circle, green
  success card), notifications (time buckets TODAY/THIS WEEK/EARLIER, tinted
  unread, shimmer loading), beneficiaries (header stats strip, gender
  avatars amber=female/green=male), reports list (local-drafts section,
  status accent bars), report detail (status banner), user management
  (role-colored avatars: admin=red, manager=green, officer=amber,
  donor=blue), NGO cards (chevron affordance), analytics (KPI tiles with
  icon circles + amber Space Grotesk numbers, demographics donut recolored
  amber=female/green=male to match beneficiary avatars, shimmer loading).
- Verified: **flutter analyze 0 issues, 44/44 tests, release web build
  compiles**, and a **live 4-role smoke test** (puppeteer keyboard-login
  against Django on :8000 local_sqlite + web build on :58569): all four
  roles logged in and every reachable screen rendered with **zero console,
  page, or API errors** — dashboards ×4, projects, reports, beneficiaries,
  notifications (via bell; note `/notifications` is NOT a GoRouter route,
  it's pushed with MaterialPageRoute from the dashboard), analytics,
  users/ngos (admin), profile, project detail, report detail, login,
  register, forgot password. Donor correctly gets the 3-tab nav.
  Smoke scripts + 33 screenshots in the session scratchpad (not committed).
- ~~Only cosmetic observation: the seeded report photo renders the grey
  fallback placeholder~~ **Fixed (same day):** the placeholder was not a
  missing file — `ReportImage.fromJson` read `json['image_url']` but the DRF
  serializer emits the ImageField as `image` (absolute URL), so the URL was
  always empty and every photo fell back. Model now reads `image` with an
  `image_url` fallback. `seed_demo` also gained `_report_photo()`: attaches
  Pillow-generated, clearly-labelled "DEMO PHOTO" JPEGs (800×600 gradient +
  caption strip; em-dash swapped for hyphen when drawing — Pillow's default
  font lacks the glyph) to the three demo reports (2/2/1), idempotent on
  caption. Verified in-browser: both photo-bearing reports render their
  thumbnails. Backend 180 tests, Flutter 44 tests, analyze 0.

---

## Premium dashboard redesign (2026-07-14, after the bug fixes)

Dashboard home rebuilt to a layered "banking app" look, per Peterson's spec:
- **Header**: green gradient (primary → new `AppColors.primaryMid` #1A6B45),
  "Smart NGO M&E" subtitle, greeting, amber role pill; right column has the
  bell (red unread badge) above a 48px amber initials avatar. Below: a
  white/10 **stats strip** (3 role-aware numbers in `accentLight` amber with
  thin dividers) that replaces the old KPI card row.
- **Layered sheet**: cream content container with 24px rounded top corners
  overlaps the header by 20px (Transform.translate; header carries 20px of
  extra bottom padding so no gap shows).
- **Quick Actions**: horizontal scrollable 100×90 chips (green icon square =
  primary action, amber tint = secondary, grey = profile), role-specific
  sets for manager/officer/admin/donor.
- **Recent Projects**: mini-cards with a 4px status-colored left accent bar,
  slim 4px progress bar, end-date + budget meta row.
- **Recent Activity**: 32px colored icon circles (green person = assignment,
  amber clock = deadline, blue check = approval, red chart = budget),
  timestamp under the text, indented dividers, "See all →".
- **Other screens**: projects list cards gained the status accent bar,
  `StatusBadge(large:)` variant, and a lazily fetched beneficiary-count
  chip; bottom nav is 68px with a top shadow and a green dot under the
  active tab; AppBars have a white/20 hairline bottom border.
- **Technical note**: `ProjectProgressBar` now fills via
  `AnimatedFractionallySizedBox` instead of `LayoutBuilder` — LayoutBuilder
  cannot compute intrinsics, which crashed inside the new `IntrinsicHeight`
  accent-bar rows.
- Verified: **44/44 Flutter tests, analyze 0 issues**; all four role
  dashboards captured live (docs/screenshots/app-dashboard-{manager,officer,
  admin,donor}.png) — each shows its own stats strip, actions, and data.

---

## Bug fixes from Peterson's UI review (2026-07-14)

### Bug 1 — GPS decimal precision ("Ensure that no more than 10 digits")
Devices report float coordinates with more precision than DECIMAL(10,7)
holds (e.g. -1.218110000000001), and DRF's DecimalField rejected them
**before** any `validate_*` method ran.
- **Backend** (`apps/reports/serializers.py`): `gps_latitude`/`gps_longitude`
  redeclared without digit limits so raw values reach the validators;
  `validate_gps_latitude`/`validate_gps_longitude` round to 7 dp via a shared
  `_round_coordinate()` helper and range-check (±90 / ±180, which also caps
  the integer digits). 4 new tests (rounding accepted, out-of-range lat/lng
  rejected, null still allowed).
- **Flutter** (`submit_report_screen.dart`): coordinates rounded to 7 dp at
  capture time (`toStringAsFixed(7)`).

### Bug 2 — Reports list "Failed to load" for officer
Not an auth/server problem: `/api/v1/reports/` returned 200 for the officer.
Root cause was client-side parsing — DRF serialises DecimalFields as JSON
**strings** (`"gps_latitude": "-0.1022000"`), and `Report.fromJson` used
`as num?`, which throws on strings and failed the whole list parse. It only
surfaced now because the seeded reports are the first with non-null GPS.
- **Flutter** (`models/report.dart`): GPS fields parsed via a tolerant
  `_asDouble()` (accepts string, number, or null). 2 new model tests.

### Verification
- Backend: **180/180 tests**; Flutter: **44/44 tests**, analyze 0 issues.
- Live end-to-end as officer1@demo.ngo with the exact bug coordinates
  (-1.218110000000001, 36.887390000000004): create → 201 with values rounded
  to -1.2181100/36.8873900 → photo upload 201 → submit → report appears in
  the list with 1 image. Web app rebuilt and re-served with the fix.

---

## Previous session (2026-07-13): Complete UI Overhaul

### Complete UI overhaul (single job, all screens)
Every screen redesigned to the design-system spec. See PROGRESS.md
"Complete UI Overhaul (2026-07-13)" for the full checklist. Highlights:

- **Shared widget library** (`mobile/lib/shared/widgets/`): StatusBadge
  (status pills on tint backgrounds), ProjectProgressBar (animated
  green→sage gradient), KpiCard, SectionHeader, EmptyState, ShimmerCard/
  ShimmerList, InfoChip. All screens consume these — no per-screen badge or
  shimmer implementations remain.
- **Theme**: AppColors gained the tint palette (success #166534/#DCFCE7,
  warning #92400E/#FEF3C7, danger #991B1B/#FEE2E2, info #1E40AF/#DBEAFE,
  neutral); cards are 12px radius / elevation 2; FABs are primary green;
  bottom nav is 64px.
- **Biggest reworks**: Dashboard (role-aware KPIs + quick actions + recent
  projects + activity feed), Submit Report (4-step wizard with project
  selector — drafts resume into it), Create/Edit Project (Details →
  Budget & Timeline → Team with officer multi-select; edit mode added),
  Project Detail (header badges, info grid, tab-aware FAB, add-milestone/
  indicator/assign-officer bottom sheets).
- **New deps**: url_launcher (View-on-Maps in report detail).

### Backend changes
- `UserManagementViewSet`: list/retrieve now allow managers (own-NGO scoped,
  read-only) so they can pick officers for teams; writes remain admin-only.
  4 new tests cover the boundary (manager list OK / cross-NGO hidden /
  officer+donor denied / manager create 403).
- `seed_demo` rewritten to the demo spec: Green Earth Initiative,
  HealthBridge Kenya, EduReach Africa; 3 Green Earth projects (Clean Water
  Kisumu active 2.4M / Girls Education Baringo planning 1.1M / Food Security
  Turkana on-hold 5.8M) with milestone mix (incl. one overdue), indicators,
  12 Kenyan-named beneficiaries, draft/submitted/approved reports, and 5
  manager notifications for the activity feed. Password for all demo
  accounts: `DemoPass123!`.

### Verification — all green
- **Backend: 176/176 tests** (`pytest`, test_sqlite settings).
- **Flutter: 42/42 tests**, `flutter analyze` 0 issues,
  `flutter build web` succeeds.
- Dev DB flushed and re-seeded; verified live: manager login → role-filtered
  dashboard stats match seed; manager `/users/` now 200; 3 projects listed
  with correct statuses/budgets; built web app renders the new login screen
  (headless Chrome screenshot).

## Servers Left Running
- Django API: `http://localhost:8000` (local_sqlite settings, background)
- Flutter web (built): `http://localhost:58569` (python http.server)
- Demo login: `manager@demo.ngo` / `DemoPass123!`

## Known Issues / Warnings
1. The dev DB was **flushed** — previous manual accounts
   (petersonmwero@gmail.com etc.) are gone; use the seeded demo accounts or
   re-register.
2. Donor quick actions deviate slightly from the spec ("Download PDF"
   replaced with View Analytics/Notifications — project PDFs are reachable
   from a project's detail via API; no dedicated PDF button yet).
3. Reports bar chart shows counts by status (draft/submitted/approved), not
   a 6-month trend — the analytics endpoint doesn't expose monthly series.
4. "Member since" row omitted from Profile (not in the /auth/me/ payload).
5. Web drafts remain in-memory (sqflite has no web implementation, D-010).

## Exact Next Steps (in order)
1. Peterson: click through the app at http://localhost:58569 with the demo
   accounts (each role renders a different dashboard) and flag any visual
   issues.
2. Optional: retake docs/screenshots with the new UI for the report.
3. Optional backlog: monthly report series endpoint for a real 6-month bar
   chart; donor PDF download button; user detail/edit screen.

## Commands to Re-run on Resume
```bash
# Backend tests (176 expected)
cd /Users/admin/Desktop/SmartNGO/backend && source venv/bin/activate
DJANGO_SETTINGS_MODULE=config.settings.test_sqlite pytest --tb=short -q

# Dev server + demo data
DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py runserver 0.0.0.0:8000
DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py seed_demo  # idempotent

# Flutter (42 tests expected)
cd /Users/admin/Desktop/SmartNGO/mobile
flutter analyze && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## Blockers
None.
