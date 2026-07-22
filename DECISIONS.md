# DECISIONS.md — Architectural Decisions Log
### Smart NGO M&E Application | Peterson Ruwa | UEAB

This file records every deliberate deviation from the CLAUDE.md specification,
with the reason for the deviation. All decisions here are permanent unless
explicitly reversed and documented as such.

---

## D-001 — Python 3.9.6 instead of 3.12

**Spec says:** Python 3.12  
**Actual:** Python 3.9.6  
**Reason:** System Python on the development machine is 3.9.6. The project
venv was created against this version. All backend code is fully compatible
with 3.9+ and no 3.12-only features are needed.  
**Impact:** Low. No features blocked. Type hint syntax stays compatible.  
**Action to reverse:** Create a new venv against Python 3.12 and reinstall;
run `pytest -q` to confirm no breakage.

---

## D-002 — Django 4.2 LTS instead of 5.x

**Spec says:** Django 5.x  
**Actual:** Django 4.2.30 (LTS)  
**Reason:** Django 4.2 is the current Long-Term Support release (supported
until April 2026). It was installed at project start and all migrations,
signals, and ORM usage are fully compatible. Upgrading to 5.x mid-project
risks breaking changes without clear benefit for the assessed features.  
**Impact:** Low. No Django 5.x-exclusive feature is required by the SDD.  
**Action to reverse:** `pip install "Django>=5.0"`, run `python manage.py
check`, run full test suite, fix any deprecation breakage.

---

## D-003 — Flat requirements.txt instead of split base/dev/prod

**Spec says:** `requirements/base.txt`, `requirements/development.txt`,
`requirements/production.txt`  
**Actual:** Single `requirements.txt` at `backend/requirements.txt`  
**Reason:** The project was bootstrapped with a single file before CLAUDE.md
was added. All packages (including test tools) are pinned to exact versions.  
**Impact:** Minor. Production deployments will install test tools (pytest etc.)
unnecessarily. No security or correctness issue.  
**Action to reverse:** Split the file into three, update Dockerfile/deploy
scripts. This is a Step 2 task.

---

## D-004 — Exception handler at config/exceptions.py, no backend/core/ directory

**Spec says:** `backend/core/exceptions.py`, `backend/core/pagination.py`,
`backend/core/responses.py`, `backend/core/utils.py`  
**Actual:** Exception handler lives at `config/exceptions.py`. No `core/`
directory exists. Pagination is configured inline in DRF settings.  
**Reason:** The config/ module was the natural home for infrastructure code
at project start. The custom exception handler (`custom_exception_handler`)
returns `{error, code}` for errors correctly.  
**Gap remaining:** There is no `core/responses.py` producing a
`{status, data, message}` success envelope. Success responses return raw DRF
serializer data. This deviates from the spec's response contract.  
**Action to reverse:** Create `backend/core/` with responses.py; add a
`SuccessResponse` helper; optionally wrap all ViewSet responses. This is a
Step 2 task.

---

## D-005 — No services.py — business logic in views/serializers

**Spec says:** "Never mix business logic into views/serializers — use service
layer functions." Each app should have `services.py`.  
**Actual:** Business logic (e.g. report workflow enforcement, token
generation) lives directly in views and serializers. The only service file
is `notifications/services.py` (notify() helper).  
**Reason:** The project was built iteratively before CLAUDE.md was added.
Views are clean DRF ViewSets; serializers handle validation. Most of what
would go in `services.py` is already isolated in serializer `validate_*`
methods or ViewSet `perform_create/perform_update` overrides.  
**Impact:** Medium. Harder to unit-test business logic in isolation; harder
to reuse logic across views. Supervisor may note the absence.  
**Action to reverse:** Extract token generation logic from accounts/views.py
into accounts/services.py; extract report workflow validation into
reports/services.py. This is a Phase 5 polish task.

---

## D-006 — Flat repository pattern in Flutter instead of Clean Architecture

**Spec says:** Feature-based Clean Architecture with `data/`, `domain/`,
`presentation/` sub-layers per feature.  
**Actual:** Flat feature folders: each feature has a `*_repository.dart`,
a `models/` subfolder, and a `screens/` subfolder. No domain entities or
use-case classes.  
**Reason:** The Flutter app was built before CLAUDE.md was added. The
repository pattern used is clean and testable — repositories are injected
via Provider, tested in isolation with mock adapters, and screens never
call Dio directly. The Clean Architecture layering would add significant
boilerplate without changing the observable behaviour of the app.  
**Impact:** Medium. A supervisor familiar with Clean Architecture may note
the absence of use-case classes and domain entities. The code is still
well-structured and testable.  
**Action to reverse:** This would require restructuring every feature folder
and is a large refactor. Recommended only if the supervisor specifically
asks for it.

---

## D-007 — Provider instead of Riverpod; no GoRouter

**Spec says:** "Provider or Riverpod" (acceptable either), GoRouter for
navigation with role-based route guards.  
**Actual:** Provider used for state management (AuthProvider,
NotificationsProvider). Navigation uses raw MaterialPageRoute push/pop.
GoRouter is not installed.  
**Reason:** Provider was installed at project start and works correctly.
GoRouter was not installed; screens were wired with MaterialPageRoute
before the navigation requirement was reviewed.  
**Impact:** Medium for navigation. Without GoRouter, deep-linking and
route guards are harder to implement. Role enforcement happens at the
widget level (hiding buttons/screens) rather than at the route level.  
**Action to reverse:** Install GoRouter, define named routes with redirect
guards that check AuthProvider.user.role, replace all Navigator.of(context)
push calls. This is a Step 3 task.

---

## D-008 — Permission class naming: IsSystemAdmin not IsNGOAdmin

**Spec says:** Permission class named `IsNGOAdmin`.  
**Actual:** Class is named `IsSystemAdmin` (in `apps/accounts/permissions.py`).  
**Reason:** "System Admin" more accurately describes the role — it is a
platform-wide administrator, not an admin scoped to one NGO. Renaming to
IsNGOAdmin would be misleading.  
**Impact:** Trivial. Tests use IsSystemAdmin throughout. No external contract
broken.  
**Action to reverse:** Rename if supervisor requires exact name match.

---

## D-009 — Milestones in apps/projects/, not a separate milestones app

**Spec says:** `apps/milestones/` as a separate Django app.  
**Actual:** MilestoneViewSet, Milestone model, and MilestoneSerializer all
live inside `apps/projects/` (models.py, views.py, serializers.py).
Milestones are registered on the router as a top-level resource
(`/api/v1/milestones/`) so the API contract is unchanged.  
**Reason:** Milestones are tightly coupled to projects (they always belong
to a project, share the ProjectScopedViewSetMixin, and are never referenced
outside the project context). A separate app would only add indirection.  
**Impact:** Low. API behaviour is identical to spec. No test coverage lost.

---

## D-010 — Report drafts are local-only (sqflite); web falls back to in-memory

**Spec says:** sqflite for "Local DB (drafts)"; the API also has a server-side
draft status (reports created as status=draft, then submitted).
**Actual:** The mobile "Save draft" button saves to a local sqflite database
(`report_drafts` table via `DraftStore` in `features/reports/draft_store.dart`)
instead of creating a server draft. "Submit" creates the report on the server
and transitions it to submitted in one flow, deleting the local draft it came
from. Local drafts appear in the Reports list under the All/Drafts filters
with a "Local draft" badge and are resumable (pre-filled Submit form). The
server draft workflow (draft → submitted → approved) remains fully supported
by the API for other clients.
**Reason:** (1) Offline-first — field officers can capture work with no
connectivity, which server drafts cannot do. (2) Server drafts created from
the app were stranded: the app has no edit-report screen, so they could never
be resumed. Local drafts are resumable by design.
**Web caveat:** sqflite has no web implementation, so on web (the dev/demo
target) `InMemoryDraftStore` is provided instead — drafts last only for the
browser session. On Android/iOS drafts persist in SQLite as specified.
Draft-store tests run against real SQLite via `sqflite_common_ffi`.
**Impact:** Low. Backend contract unchanged; 172 backend tests unaffected.
**Action to reverse:** Reinstate the server `createReport` call in
`_saveDraft()` and drop the DraftStore wiring.

---

## D-011 — Kenya ward locations keyed by (constituency, ward)

**Context:** The cascading location picker's reference data
(`apps/beneficiaries/kenya_locations.py`) originally keyed `WARD_LOCATIONS` by
bare ward name. Ward names are not unique nationally: 79 of them are shared
across the 290 constituencies (e.g. "Biashara" is a ward in Nakuru Town East,
Naivasha and Ruiru), so a bare-name lookup returned the same locations for
every same-named ward.
**Decision:** `WARD_LOCATIONS` is now built keyed by the `(constituency, ward)`
pair, from the curated lists plus a generated `"<ward> A/B"` fallback. A curated
list belongs to exactly one constituency; when the ward name is ambiguous,
`CURATED_WARD_CONSTITUENCY` pins the intended one and the others fall back to
generated locations. Reads go through `locations_for_ward(constituency, ward)`,
and the `/locations/kenya/` endpoint takes `constituency` alongside `ward`
(checked before the bare-constituency → wards case). A `ward` without a
`constituency` degrades to generated locations rather than guessing another
constituency's list.
**Reason:** Correctness — only "Biashara" had a curated list under the old
scheme, and it leaked to Naivasha's and Ruiru's Biashara wards. Keying by the
pair is the minimal structural fix; the pin keeps the one genuinely ambiguous
curated entry unambiguous without hand-reorganising all 37 curated lists.
**Impact:** Low. The stored `Beneficiary.ward`/`location` fields are free
strings, so no data migration is needed; only the picker's lookup changed. The
Flutter picker passes the selected constituency it already holds. Covered by an
API-level regression test (Nakuru vs Naivasha "Biashara").
**Action to reverse:** Re-key `WARD_LOCATIONS` by bare ward name and drop the
`constituency` argument from `locations_for_ward` and the endpoint's ward
branch.
