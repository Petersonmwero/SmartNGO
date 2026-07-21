# Session Handover — 2026-07-21 | True PV-based SPI

---

## True PV-based SPI (2026-07-21)

The old `schedule_performance_index = physical / time` silently assumed a
straight-line plan. SPI is now **EV / PV** per PMBOK, with Planned Value
derived from the phase baseline:

- `Project.planned_value_progress` — Σ(phase.allocated_budget ×
  elapsed fraction of that phase's own window) / budget × 100, capped at
  100. Helper `_elapsed_fraction(start, end, today)` is module-level in
  `apps/projects/models.py`; its `today >= end` check comes first so a
  zero-length phase window can never divide by zero.
- `schedule_performance_index = physical_progress / planned_value_progress`
  (the budget cancels — both are percentages of it). `None` when PV is 0,
  meaning no work was *scheduled* to have started yet; previously `None`
  keyed off the project start date.
- **Documented fallback**: a project with no phases, or a non-positive
  budget, falls back to `time_progress`. The whole old model survives only
  as this degenerate case.
- `planned_value_progress` is read-only on `ProjectSerializer`. **No
  migration** — everything is a computed property.
- Untouched on purpose: `cost_performance_index`, `progress_percentage`,
  the 30/50/20 weights, `health_status`.

**Why this matters for the demo**: Food Security is front-loaded (PV 49%
vs 34% calendar), so its SPI now reflects the plan it was actually given.

**Verification**
- `215 backend tests pass` (was 208; 7 new PV tests in
  `apps/projects/tests/test_progress_evm.py`).
- Dev DB flushed + reseeded, then PV/T/CPI/SPI/health printed per project:
  Girls Education healthy (SPI 1.11 → **1.02**), Clean Water critical
  (0.36), Food Security critical (0.20), Community Clinic not_started.
  Variety intact — **seed data was not retuned**.
- Flutter: `ProjectHealthCard` SPI wording changed from schedule language
  to "Ahead of / Behind planned work" (+ "No work scheduled yet" for null),
  since the formula no longer measures calendar elapsed. `flutter analyze`
  0 issues, 47/47 tests.

### Flutter wiring of PV (same day, follow-up)

- `Project.plannedValueProgress` parses `planned_value_progress` via
  `ProjectPhase.asDouble`, so a pre-PV payload degrades to `0` instead of
  throwing.
- `ProjectHealthCard` SPI row gained a muted footnote — "Earned 20.0% of
  budgeted work vs 19.7% planned" — making the index traceable to the phase
  baseline. `_IndexRow` took an optional `footnote` for this.
- Printed to **one decimal on purpose**: rounding both sides to whole
  percents renders "20% vs 20%" beside an SPI of 1.02, which reads as a bug.
- New `test/features/projects/project_health_card_test.dart` (3 tests):
  PV parsing incl. the missing-key fallback, the behind-plan footnote, and
  the "No work scheduled yet" null case. **50 Flutter tests**, analyze 0.

**Live verification gotcha**: the first browser pass showed SPI 1.11 and
"vs 0% planned" — the demo Django server runs with `--noreload`, so it was
still serving pre-change code. Restarted it, re-shot, then confirmed by eye:
Girls Education SPI 1.02 / "20.0% vs 19.7% planned" (healthy), Food Security
SPI 0.20 / "10.0% vs 49.0% planned" (critical, and the clearest demo of a
front-loaded plan: 49% planned vs 34% calendar). Zero console/API errors.
**Restart the runserver process after backend edits** — it will not reload
itself.

`docs/screenshots/app-project-detail.png` **retaken** scrolled to the health
card (Food Security: CRITICAL, CPI 0.20, SPI 0.20, "Earned 10.0% of budgeted
work vs 49.0% planned") plus the phase budget table. Repeatable via
`detailshot.js` in the session scratchpad — manager login, Projects, row 1,
`mouse.wheel({deltaY: 555})`; 620 clips the card header, so re-tune the
scroll by eye if the layout above it changes.

### Full screenshot set retaken against the reseeded data

All 13 `app-*.png` recaptured in one run (`docshots.js` in the session
scratchpad; takes an output dir + an optional comma-separated subset, so a
single frame can be redone without the whole set). Zero console/API errors.
Only 8 files actually changed — `app-login`, `app-beneficiaries`,
`app-analytics`, `app-profile` and `app-submit-report` came out
byte-identical, since nothing in them depends on the shifted seed dates.

The notification-bell race from `afbfa73` is handled in the script: it
re-navigates to the dashboard, waits 6s for the KPI fetches to settle, then
taps the bell at (343, 40). Tapping earlier loses the route push to a
re-render and silently captures the dashboard instead.

> **Bug found while eyeballing `app-dashboard-admin.png`** (pre-existing, NOT
> fixed — it changes RBAC behaviour and demo numbers): the admin stats strip
> reads "3 Projects" while the Recent Projects list right below it shows
> Community Clinic Outreach, which belongs to a *different* NGO. Cause:
> `apps/analytics/views.py::_projects_qs` scopes admins to `user.ngo`, but
> `/projects/` returns all 4 across NGOs (verified via the API). CLAUDE.md
> business rule 1 says a system-wide admin sees all NGOs, so the dashboard
> queryset is the side that is wrong. Fixing it moves the admin dashboard
> counts and will touch the analytics tests.

The top of the same screen — date/budget tiles + `ProjectProgressCard`
(27% composite ring, financial/physical/time bars) — is now a second file,
`docs/screenshots/app-project-progress.png` (same script, scroll `0`), so the
detail screen is documented top-to-bottom across the two frames. No markdown
references either filename yet; they are used directly in the report.

---

## Weighted Composite Progress / EVM (2026-07-18, commit `9e38da6`)

Project progress is no longer "% of timeline elapsed" — it is a weighted
composite per PMBOK Earned Value Management:
**Financial × 30% + Physical × 50% + Time × 20%** (weights are constants on
the `Project` model).

**Backend** (built in the interrupted session, verified + committed here):
- `ProjectPhase` (`project_phases` table): phase_name/type
  (planning/implementation/monitoring/closeout), allocated_budget,
  spent_budget, dates, status. Nested CRUD at
  `/projects/{id}/phases/` — reads for any authenticated user in the
  project's NGO, writes manager/admin. Phase spend drives financial
  progress, so any spend edit changes composite progress on next read (all
  computed properties, no caching).
- `Milestone.weight` (PositiveInteger, default 1; serializer bounds 1–10).
  Physical progress = completed weight / total weight.
- `Project` computed properties: financial/physical/time progress,
  progress_percentage (composite), total_spent, budget_remaining,
  cost_performance_index (physical/financial, None until spend),
  schedule_performance_index (physical/time, None before start),
  health_status (both ≥0.95 healthy, ≥0.8 at_risk, else critical; CPI or
  SPI None → not_started). All read-only on ProjectSerializer; list
  queryset prefetches phases+milestones (N+1 guard).
- Migration `0002_milestone_weight_projectphase` (already applied to dev
  DB by the previous session). `seed_demo`: 14 phases + weighted
  milestones tuned so demo shows variety — Girls Education healthy
  (CPI 1.00/SPI 1.11), Clean Water critical (72% spend vs 25% delivery),
  Food Security critical (50% vs 10%), Clinic not_started.
- **Gotcha fixed**: the interrupted session had rewritten
  `test_auth.py` to post `full_name` — but the API uses
  first_name/last_name (full_name is a computed property). Reverted to
  HEAD; **208 backend tests pass** (incl. new `test_progress_evm.py`).

**Flutter** (completed this session):
- `models/phase.dart` (+ `ProjectPhase.asDouble` for DRF decimal
  strings); `Project` model gained all EVM fields + `compositeFraction`,
  `dimensionSummary` ("F: x% · P: y% · T: z%"), `healthLabel/healthColor`;
  `Milestone.weight`; repository phase CRUD + weight on createMilestone.
- `widgets/evm_cards.dart`: `ProjectProgressCard` (64px composite ring,
  3 dimension bars with detail lines like "KES 220K of 1.10M spent" /
  "2 of 10 milestone weights delivered" / "36 of 200 project days"),
  `ProjectHealthCard` (rating badge + CPI/SPI with plain-language
  readings), `PhaseBudgetTable` (green-headed ALLOC/SPENT/UTIL table,
  TOTAL row, MANAGE PHASES action for manager/admin), `HealthDot`.
- `screens/phase_management_screen.dart`: phase list cards with
  utilization bars, add/edit bottom sheet (type/status dropdowns, date
  pickers, amount validation), delete confirm; pops `true` so the detail
  screen refetches ("progress recalculated" snackbars).
- Project detail: Overview tab shows the 3 EVM cards after the info
  grid (old "Timeline elapsed" card removed); header badge now
  "N% complete" (composite); Add Milestone sheet gained a weight
  dropdown (1 — Minor / 5 — Major / 10 — Critical); milestone cards
  show "· Weight N".
- Projects list rows: composite % + bar, HealthDot beside the name,
  dimensionSummary line. Dashboard RECENT PROJECTS rows: composite % +
  HealthDot.
- Verified: analyze 0, **47/47 tests**, live browser pass as manager —
  dashboard rows, project register (breakdown lines + dots), Girls
  Education detail (all three cards render with correct numbers),
  MANAGE PHASES screen, milestones tab with weights — zero console/API
  errors. Screenshots in session scratchpad (evm-*.png).
- Dev DB was **flushed + reseeded** (old seed milestones were renamed;
  get_or_create would have duplicated them). Demo photos re-seeded fine
  (3 reports / 5 images).
- Docs screenshots **retaken 2026-07-20** against the EVM build — 10 of
  14 PNGs updated (project detail now shows the PROGRESS + HEALTH cards,
  projects list + dashboards show composite % and health dots; analytics/
  beneficiaries/notifications/reports shifted only on relative
  timestamps). Login/submit-report/register-beneficiary byte-identical.
  Committed `d45d2b6`.
- **Screenshot gotcha + fix (`afbfa73`)**: the batch `docshots.js` run
  produced a wrong `app-notifications.png` — the bell tap (350,38) fired
  before the dashboard finished re-rendering after the profile→home hash
  change, so it landed on empty space and captured the dashboard instead.
  The run still reported "no console/API errors" (a missed tap is a silent
  no-op), so **visually verify each shot, don't trust the error count**.
  Recaptured with `notifshot.js` (fresh login → 7s settle → bell at
  (343,40) → 4s for the MaterialPageRoute push); the PNG now shows the
  real notifications screen. All 14 confirmed correct by eye.
- Session state: Django :8000 (nohup, /tmp/smartngo-django.log) + web
  :58569 (nohup, /tmp/smartngo-web.log) serving the new build;
  evmshot.js/phaseshot.js in the session scratchpad (reuse the
  4aa33d74 scratchpad's node_modules via NODE_PATH).

---

## UI review fixes round 2 (2026-07-17, from Peterson)

- **Stats strip**: dashboard MY STATISTICS reverted from 2×2 grid to a
  compact horizontal 4-box strip (flush coloured surfaces, 1px separators,
  20px icons, 22px numbers, 10px labels — at that size "Beneficiaries"
  fits, which is why the 2×2 compromise existed). OfficialCard gets
  contentPadding: zero there so the strip runs edge-to-edge.
- **Project rows**: dashboard RECENT PROJECTS rows now show a meta line
  under the (link-blue) name — calendar icon + "d MMM yyyy" end date and
  $-icon + KES budget.
- **Subtitles**: BENEFICIARY REGISTER gained "N beneficiaries registered";
  ANALYTICS DASHBOARD gained "Smart NGO M&E — <NGO name>" (NGO name
  resolved best-effort via NgoRepository.listPublic like the profile
  screen; falls back to the system name). Projects/reports subtitles
  already existed from the redesign.
- Verified: analyze 0, 47/47 tests, live capture of the dashboard
  (stats strip + meta rows) and both AppBar subtitles; docs screenshots
  refreshed.
- Pushed as `2a7252c`. Session state: Django :8000 (nohup,
  /tmp/smartngo-django.log) + web :58569 serving the current build;
  puppeteer scripts (docshots.js, regshot.js, smoke1-14) in the session
  scratchpad.
- 2026-07-17 re-verification: full docs screenshot set recaptured live —
  all 13 byte-identical to the committed set (zero console/API errors),
  confirming repo, docs, and demo environment are in sync. Nothing else
  outstanding; the project is demo-ready.

---

## Dashboard visual richness pass (2026-07-16, on top of eCitizen redesign)

Structure kept, colour depth added per Peterson's spec:

- **Header**: 6px flag ribbon with drop shadow; 3-stop diagonal green
  gradient (primaryDark → primary → #007A3D); 48px logo box with gold
  divider line + shadow; user-info bar on a #003D1F→primaryDark gradient
  with a 2px gold bottom rule; plus a 3px gold-gradient accent bar between
  header and content.
- **Welcome banner**: green gradient card with glow shadow, waving-hand
  icon in a white/20 circle, white text, chevron.
- **MY STATISTICS**: coloured stat boxes (green Projects / blue
  Beneficiaries / amber Reports / red Pending) with tinted icon circles.
  **Deviation from spec**: laid out 2×2 instead of 4-across — at 430px the
  4-across row clips "Beneficiaries" (same overflow class Peterson flagged
  in his UI review); 2×2 keeps every label intact.
- **QUICK SERVICES**: tiles now carry 52px gradient icon squares with
  colour-matched glow (green/amber/blue/purple per service, all roles).
- **OfficialCard**: default left rule is now GOLD (the eCitizen signature)
  with green titles — applies app-wide (profile, analytics; SYSTEM ACTIONS
  keeps its red override); new `gradientHeader:` variant (green gradient,
  white title, gold action) used by RECENT PROJECTS / RECENT ACTIVITY.
- **Project rows**: progress bar + 3px right border in the status colour.
  **Activity feed**: timeline style — colored node circles with rings,
  connector lines, title + message, colour-matched timestamp.
- Background app-wide: #F5F5F5 → **#F0F2F5** (blue-tinted grey);
  bottom nav gold rule 2px + black12 shadow.
- Verified: analyze 0, **47/47 tests**, web build; all 4 role dashboards
  captured live incl. scrolled view (pinned header confirmed); docs
  screenshots refreshed.

---

## eCitizen-inspired official UI (2026-07-16, full design-language swap)

Whole app restyled to Kenya-government/eCitizen look per Peterson's spec:
Kenya green #006633 + gold #CC9900, white structured cards, squared corners
(2-4px), Inter-only typography, table-style data.

- **Foundation (repaints every screen automatically)**: `AppColors` values
  swapped to the eCitizen palette while KEEPING legacy constant names as
  aliases (primaryMid, accentLight, charcoal, muted, tints…) so untouched
  screens (splash, register, forgot password, project detail, submit
  wizard, admin screens, picker) adopted it without edits. ThemeData: Inter
  everywhere (Space Grotesk dropped), AppBars green with a **2px gold rule**
  (shape border), buttons 48px/radius-2, inputs radius-2 with #BBBBBB
  borders, cards bordered radius-4, snackbars squared.
- **New shared widgets** (`shared/widgets/official_card.dart`):
  `OfficialCard` (grey header strip, 4px green left rule, uppercase title,
  optional VIEW ALL action), `FlagRibbon` (5-band Kenya strip — NOTE: a
  childless ColoredBox in a Row collapses to zero height; needs
  crossAxisAlignment.stretch), `InfoRow` (label/value table row).
  StatusBadge → official bordered uppercase style; on_hold now red.
- **Dashboard**: official header (flag ribbon, white NGO/M&E text-logo
  block, system name, bell w/ red badge, gold avatar, primaryDark user-info
  bar with "Last login: Today"), welcome notice banner, MY STATISTICS
  4-stat card, QUICK SERVICES 3-col tile grid (role-aware), RECENT
  PROJECTS dot+badge+progress table rows, RECENT ACTIVITY timestamp-column
  log rows.
- **Login**: government header (ribbon, 60px logo square, SMART NGO /
  M&E SYSTEM / Baraton line), SYSTEM LOGIN card, blue Forgot Password,
  SIGN IN TO SYSTEM + CREATE NEW ACCOUNT, © footer. All keys/logic kept
  (email_field/password_field/login_button, resend-verification flow).
- **Tables**: projects (PROJECT NAME|STATUS|PROGRESS), reports (REPORT
  TITLE|TYPE|STATUS, officer+date under title), beneficiaries
  (NAME|AGE|STATUS with location—project under name) — green column
  headers, alternating white/#F8F8F8 rows, link-blue titles; search +
  Filter popup bars on white.
- **Profile**: identity strip + ACCOUNT INFORMATION InfoRow table +
  SECURITY & SETTINGS + red-ruled SYSTEM ACTIONS sign-out.
  **Notifications**: action bar (N unread + Mark All Read), flat log rows
  (gold left rule + amber surface when unread). **Analytics**: green
  summary bar + OfficialCard chart sections + demographics table row.
  **Nav bar**: 3px gold top rule, primarySurface indicator.
- **Fixes en route**: Container(color:)+decoration assert in the
  notifications action bar; ShimmerCard now adapts line count to height
  (3-line body overflowed 56px table-row placeholders).
- Verified: analyze 0, **47/47 tests**, web build; all 4 roles logged in
  live and every tab/screen captured (docs screenshots now show the
  official UI). Puppeteer coordinate updates: dashboard bell moved to
  (350,38); officer Submit Report service tile at (87,467).

---

## Sub-location dropdown removed (2026-07-16, per Peterson)

Picker simplified to 5 dropdown levels + free text: Country (locked) →
County → Constituency → Ward → Location, then a "Village / Sub-location"
TextFormField (hint "e.g. Taru, Samburu, Mwamdudu...") where users type
their own area. Flutter-only change:

- `kenya_location_picker.dart`: sub-location dropdown, state, loader, and
  emit key removed; Location is now the last cascading level.
- Register screen no longer passes subLocation to create().
- **Backend untouched by design**: the `sub_location` model field, the
  `?location=` API level, LOCATION_SUBLOCATION data, and the repository's
  `kenyaSubLocations()` all remain (new records just leave sub_location
  empty). The list-card summary getter still includes subLocation first,
  so old seeded rows keep their display; new rows show
  "Location · Ward · Constituency".
- Verified: analyze 0, **47/47 tests** (picker test asserts the dropdown
  is gone), web rebuilt; live E2E Baringo → Baringo Central → Kabarnet →
  Kabarnet → typed "Kapsoo Village" → submitted; list shows
  "Kabarnet · Kabarnet · Baringo Central". Test record soft-deleted.
- `docs/screenshots/app-register-beneficiary.png` retaken with the new
  5-level form.
- Pushed as `070ad45`; docs refreshed `8a210c6` (only the 4 dashboard
  PNGs changed — greeting/timestamps). Session state unchanged: Django
  :8000 (nohup) + web :58569 serving the new build; puppeteer scripts
  (docshots.js, smoke1-13) in the session scratchpad.

---

## Ward data completed for all 290 constituencies (2026-07-16)

- `CONSTITUENCY_WARDS` now covers **every constituency** (1,378 ward
  entries; verified: no duplicate dict keys, zero constituencies missing).
  Sources: existing curated tables kept authoritative; Peterson's supplied
  lists merged for the previously-missing counties, with corrections:
  "Lungalunga"→"Lunga Lunga", "Mt Elgon"→"Mt. Elgon", his "West Pokot"
  constituency entry re-keyed to **Kapenguria** (the ward list he supplied
  is Kapenguria's), "Mau Narok" and "Murang'a South" skipped (not real
  constituencies — added real **Kangema** wards instead), **Busia county
  was absent from his paste** — real wards added for its 7 constituencies,
  and Ndia's ward list fixed (it contained "Nairobi").
- **Locations for the ~1,200 new wards are generated**, not hand-written:
  a `setdefault` loop at the bottom of kenya_locations.py gives any ward
  without curated data "<ward> A"/"<ward> B" locations (per Peterson's
  A/B/C instruction). Curated lists always win. Sub-locations for
  generated locations stay empty → picker shows "skip".
- Known limitation (pre-existing): the dicts are keyed by bare name, so
  same-named wards in different constituencies (e.g. "Township" ×many)
  share one location list — 1,282 unique ward names vs 1,378 ward entries.
  A future fix would key by (constituency, ward).
- New integrity tests: every constituency has non-empty wards; every ward
  has locations. **195 backend tests pass.** No Flutter changes needed
  (the picker already handled data-present paths).
- Verified: API spot-checks across 6 counties (Kwale/Kinango incl.
  generated locations, Nairobi/Westlands unchanged, Bungoma, Machakos,
  Siaya, Kericho) + live browser cascade through **Bomet → Sotik →
  Ndanai/Abosi → Ndanai/Abosi A** — the exact path that previously showed
  "No ward data — skip".
- **All pushed**: ward data `eca21ca`, PROGRESS `1949b72`, screenshot
  refresh `694e7b0` (only officer-dashboard + notifications PNGs changed —
  timestamps; the ward work is backend-only). app-register-beneficiary.png
  intentionally kept on the curated Kabarnet full-depth cascade.
- Session state: Django :8000 (nohup, /tmp/smartngo-django.log) + web
  :58569 both serving the complete dataset; puppeteer scripts
  (docshots.js, smoke1-12) in the session scratchpad.

---

## Kenya hierarchy extended to 5 levels (2026-07-16, same day as v1)

Picker now runs County → Constituency → Ward → Location → Sub-Location
(+ free-text Village), per Peterson's spec.

- **Data integrity decision**: Peterson's pasted constituency/ward tables
  contained regressions vs. the verified data already in the repo ("Mau
  Narok" as a Nakuru constituency — it's a Njoro ward; "West Pokot"
  constituency replacing Kapenguria; Baringo South given Eldama Ravine's
  wards; several Turkana wards on the wrong constituency). Kept the
  existing verified tables and **added** the two new levels from his data,
  re-keyed to the repo's ward spellings (Marioshoni→Mariashoni). New
  integrity tests pin this: every WARD_LOCATIONS key must be a real ward,
  every LOCATION_SUBLOCATION key a real location.
- **Backend**: `WARD_LOCATIONS` + `LOCATION_SUBLOCATION` dicts (locations/
  sub-locations for a representative ward subset — same graceful-empty
  degradation as wards); endpoint gained `?ward=` and `?location=` params
  and counties are now returned **sorted**; model gained `location` AND
  `sub_location` fields (spec only added sub_location, but the picker emits
  location too — it must persist); the old `location` property is now the
  **field**, and the joined string moved to `full_location` (CSV export
  updated accordingly); migration 0003; seed rows carry full chains
  (e.g. Chebet: Baringo Central/Kabarnet/Kabarnet/Kabarnet A). DB flushed +
  reseeded. **193 backend tests pass** (4 new).
- **Flutter**: picker has the 2 new dropdowns (each level resets and loads
  the one below; "No location data — skip" fallback), emits
  `location`/`sub_location` (village kept as a 7th key); repository +
  model + create() extended; list cards show the 3 most specific parts
  ("Sub-Location · Location · Ward" degrading per spec). **47 tests pass**,
  analyze 0.
- **Verified live** (officer1): full-depth chain Baringo → Baringo Central
  → Kabarnet → Kabarnet → Kabarnet A registered end-to-end; list row shows
  "Kabarnet A · Kabarnet · Kabarnet". Also exercised the no-data branch
  (Bomet → ward dropdown disables with skip hint). Test record
  soft-deleted. Puppeteer driving note: with nothing selected, a Flutter
  web dropdown aligns item 1 over the button — open, then click the same
  spot (or +48px per item) to pick deterministically; arrow-key counts are
  NOT reliable.
- **All pushed**: picker v1 `78e98d0`, 5-level hierarchy `5486335`, docs
  screenshots `eb43b69` (beneficiary cards show hierarchy lines; NEW
  `app-register-beneficiary.png` shows the filled cascade — docs set is
  now 14 screenshots).
- Session state: Django on :8000 (nohup, log /tmp/smartngo-django.log —
  harness-tracked background tasks kept getting reaped, hence nohup) and
  web build on :58569; puppeteer scripts (docshots.js, smoke1-11) in the
  session scratchpad.

---

## Kenya cascading location picker (2026-07-16, eCitizen-style)

Beneficiary location upgraded from one free-text field to Kenya's
administrative hierarchy (country → county → constituency → ward → village).

**Backend**
- `apps/beneficiaries/kenya_locations.py`: all **47 counties**, the complete
  real constituency list for every county (**290**), and real ward lists for
  the demo-relevant + major counties (Nairobi, Mombasa, Kisumu, Nakuru,
  Kiambu, Baringo, Turkana — 65 constituencies). **Data gap (deliberate)**:
  constituencies in other counties return an empty ward list rather than
  fabricated names; the picker then shows "No ward data — skip" and ward
  stays optional. Extend the dict to close the gap.
- `GET /api/v1/locations/kenya/` (`KenyaLocationView`, AllowAny —
  public reference data): `?counties=true` | `?county=X` | `?constituency=X`
  → `{status, data:[...]}`; no param → 400. Unknown names → empty list, not
  an error. @extend_schema keeps Swagger at 0 warnings.
- `Beneficiary` model: `location` CharField **replaced** by `country`
  (default Kenya) / `county` / `constituency` / `ward` / `village`
  (migration 0002). A `location` @property joins them (most specific first)
  so the CSV export and any old callers keep working. Serializer exposes the
  new fields + computed `full_location`.
- seed_demo beneficiaries reseeded with real hierarchy rows (dev DB was
  **flushed** — demo report/photos re-seeded by seed_demo; E2E artifacts
  from earlier sessions are gone). Tests: **189 pass** (9 new: data
  integrity + endpoint incl. anonymous access and 400).

**Flutter**
- `shared/widgets/kenya_location_picker.dart`: fixed Kenya field (locked,
  flag), three cascading dropdowns (each selection resets+loads the level
  below; shimmer + green border while loading; disabled grey until parent
  chosen; contextual hints "Select county first"), village text field;
  emits `{country, county, constituency, ward, village}`.
- Register Beneficiary screen rebuilt into `_SectionCard`s (Personal
  Details / Location Details / Project Assignment), gender segments with
  icons, tappable DOB card with amber live-age chip, icon submit button.
- Repository: `kenyaCounties/kenyaConstituencies/kenyaWards` + create()
  takes the new fields. Model: new fields + `locationSummary` getter; list
  cards + search use "village · constituency · county".
- Tests: **47 pass** (3 new: repo cascade lookups; picker widget cascade +
  reset-on-county-change). analyze 0.

**Verified live** (officer1): county load → constituency load → ward
degrade (Kwale has no ward data) → village typed → project picked → submit
201 → green snackbar → list row shows "Mtopanga · Kinango · Kwale". Test
record soft-deleted afterwards. Driving note: Flutter web dropdowns can be
driven by click-to-open + ArrowDown/Enter, but the focused start item is
inconsistent — don't rely on arrow counts to pick a *specific* item.

`docs/screenshots/app-beneficiaries.png` still shows the old single-line
locations — retake when convenient.

---

## Premium dashboard redesign v2 (2026-07-16, after the review fixes)

`dashboard_screen.dart` fully rewritten to Peterson's fintech-grade spec:

- **Pinned header**: the gradient header no longer scrolls — layout is
  `Column[_Header, Expanded(sheet)]`, with the cream sheet stretched 28px
  taller than its slot via `LayoutBuilder + OverflowBox` and pulled up with
  `Transform.translate` so its 28px-radius corners overlap the gradient with
  no gap at the bottom (a plain translate leaves a strip; a taller-child
  SizedBox inside Expanded throws overflow — OverflowBox avoids both).
- **Header**: 3-stop diagonal gradient (0xFF0A3D24 → primary → primaryMid)
  with a faint CustomPaint dot grid (white @0.03); brand line 12px/ls 0.5,
  greeting 14px, **full name** 26px bold; glassy role pill (white/15 bg,
  white/25 border, amber role icon: admin=shield, manager=premium,
  officer=badge, donor=volunteer); bell badge now **amber 18px circle with
  1.5px green border** (kept 9+ cap); **52px amber-gradient avatar with glow
  shadow**, taps to /profile; stats strip white/12 + white/20 border, 24px
  amber numbers, **shimmer rectangles while stats load**.
- **Quick actions**: chrome-less 88px chips — 56px icon tile (green gradient
  + green glow for primary, 0xFFFFF8E7 amber tint for secondary; neutral
  style dropped), 11px w600 label under it.
- **Project cards**: dual soft shadow, 5px accent bar with top→bottom fade,
  "Progress" + green % row, 5px rounded LinearProgressIndicator in the
  accent color, InfoChip footer with `d MMM yyyy` end date + budget; shimmer
  cards while loading; role-aware empty state with Create Project button.
- **Activity feed**: single white card, 38px tinted icon circles, title +
  message lines, 10px right-aligned timestamps, 64px-indented hairline
  dividers; icon map gained report=description/green and
  budget=wallet/red (was chart).
- **SectionHeader** (shared): title bumped to 17px w700 app-wide.
- No FAB existed on the dashboard (spec's removal item was already true).
- Verified: analyze 0, 44/44 tests, web build; live all-4-roles check plus
  **pinned-header scroll** and **pull-to-refresh** (note: Flutter web only
  drag-scrolls with touch — verified via CDP touch events; mouse wheel works
  for scroll) and a 360×740 narrow-viewport pass with no overflow.
- All pushed: redesign `0c1a30b`, retaken docs screenshots `acc7400` (only
  the 4 dashboard PNGs changed — other screens render byte-identically).
- Session state: Django :8000 (local_sqlite) + web build :58569 still
  running; puppeteer scripts (docshots.js + smoke1-6) in session scratchpad.

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
  visible), and the populated submit-report dropdown.
- All pushed: fixes `ec2aaba`, retaken docs screenshots `b80b920` (11 of 13
  changed; login + one other were byte-identical), PROGRESS.md `4d5e449`.
- Session state: Django on :8000 (local_sqlite, restarted with the new
  serializer) and web build on :58569 both left running; puppeteer smoke/
  screenshot scripts live in the session scratchpad (not committed).

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
