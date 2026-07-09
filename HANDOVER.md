# Session Handover — 2026-07-09 | Gmail SMTP + Verify Success Screen

---

## Completed This Session

### Gmail SMTP + Professional Verification Email + Verify-Success Screen

- **`config/settings/base.py`**: Replaced console backend with Gmail SMTP
  (`EMAIL_BACKEND = smtp.EmailBackend`, host/port/TLS). Added
  `FLUTTER_VERIFY_SUCCESS_URL` setting (default `http://localhost:60860/#/verify-success`).
  Email credentials read from `.env` via the existing `env()` helper.

- **`config/settings/dev.py`**: Removed the `EMAIL_BACKEND = console` override so
  real SMTP is used in development. Console backend now only lives in `test_sqlite.py`.

- **`apps/accounts/views.py`**:
  - `_send_verification_email()` rebuilt with `EmailMultiAlternatives` — sends both
    plain text and an HTML version with the green globe branding, centred layout, and
    a "Verify My Email" button. Subject: "Verify your Smart NGO M&E Account".
    Greets by `user.first_name` (correct capitalisation from the model).
  - `VerifyEmailView.get()` now returns `HttpResponseRedirect(FLUTTER_VERIFY_SUCCESS_URL)`
    on success instead of JSON, so the browser lands on the Flutter confirm screen.
  - Re-added `send_mail` to imports (used by the password-reset view).

- **`backend/.env`**: Created (gitignored) with `petersonruwa@gmail.com` pre-filled.
  `EMAIL_HOST_PASSWORD` set to placeholder — Peterson fills in his App Password.

- **`backend/.env.example`**: Added `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`,
  `DEFAULT_FROM_EMAIL`, `BACKEND_BASE_URL`, and `FLUTTER_VERIFY_SUCCESS_URL` entries
  with instructions for obtaining a Gmail App Password.

- **Flutter `verify_success_screen.dart`** (NEW): Green checkmark + "Email Verified!"
  title + "Your account is now active. You can log in." + "Go to Login" FilledButton
  that routes to `/login`.

- **`mobile/lib/core/router.dart`**: Added `/verify-success` GoRoute; added it to the
  `isPublic` list so the redirect guard does not bounce unauthenticated visitors to login.

- **`mobile/lib/features/auth/screens/register_screen.dart`**: Capitalised `firstName`
  on the post-registration success screen using `[0].toUpperCase() + substring(1).toLowerCase()`.

- **`apps/accounts/tests/test_email_verification.py`**: Updated
  `test_valid_token_activates_user` to expect `302` (redirect) instead of `200`.

### Issue 1 — Re-registration allowed over unverified accounts

- **`apps/accounts/views.py` `RegisterView.create()`**: Before calling `serializer.is_valid()`,
  normalizes the email to lowercase and deletes any existing `is_active=False` user with an
  unused verification token. This lets a user re-register if their link expired.

### Issue 2 — first_name + last_name (replacing full_name)

- **`apps/accounts/models.py`**: Removed `full_name` CharField. Added `first_name`
  (max 150) and `last_name` (max 150, blank/optional). Added `@property def full_name`
  returning `f"{first_name} {last_name}".strip()` for backwards-compatible display.
  Updated `REQUIRED_FIELDS = ["first_name", "last_name"]`.

- **`apps/accounts/migrations/0003_user_first_last_name.py`**: New migration —
  RemoveField full_name, AddField first_name (preserve_default=False), AddField last_name.

- **`apps/accounts/serializers.py`**:
  - `RegisterSerializer`: explicit `first_name`/`last_name` fields (first_name required,
    last_name optional); Meta.fields updated.
  - `UserProfileSerializer` + `UserManagementSerializer`: fields updated.
  - `SmartTokenObtainPairSerializer.validate()`: login user dict now includes
    `first_name`, `last_name`, and `full_name` (property).

- **`apps/accounts/views.py`**: `UserManagementViewSet.get_queryset()` ordering
  changed from `full_name` to `("first_name", "last_name")`.

- **`apps/accounts/admin.py`**: `search_fields` changed from `("full_name", "email")`
  to `("first_name", "last_name", "email")`.

- **`apps/accounts/management/commands/seed_demo.py`**: `_user()` signature changed to
  accept `first_name, last_name` parameters; all 7 `_user()` call sites updated; seeds
  set `is_active=True` (demo users should be able to log in directly).

- **`backend/conftest.py`**: `_make_user()` uses `first_name=role, last_name="user"`.

- **Test files updated** (full_name → first_name/last_name in all payloads and
  `create_user()` calls):
  - `apps/accounts/tests/test_auth.py`
  - `apps/accounts/tests/test_email_verification.py` (12 register payloads)
  - `apps/accounts/tests/test_me.py` (field list)
  - `apps/accounts/tests/test_user_management.py` (3 places)
  - `apps/projects/tests/test_assignment_api.py`
  - `apps/reports/tests/test_report_api.py`
  - `apps/reports/tests/test_report_image_api.py`

- **Flutter `mobile/lib/features/auth/models/user.dart`**: Replaced `fullName` field
  with `firstName` + `lastName` fields; added `String get fullName` computed getter.
  `fromJson` reads `first_name`/`last_name`; `toJson` writes them.

- **Flutter `mobile/lib/features/users/user_repository.dart`** (`ManagedUser`):
  `fromJson` now builds `fullName` from `first_name` + `last_name` (with fallback to
  `full_name` for cached data).

- **Flutter `mobile/lib/features/auth/auth_repository.dart`**: `register()` signature
  changed to `firstName`/`lastName`; sends `first_name`/`last_name` to API; return type
  changed from `Future<User>` to `Future<void>` (register endpoint returns a success
  envelope, not user data).

- **Flutter `register_screen.dart`**: Single "Full name" field replaced by two
  side-by-side "First name" (required) + "Last name" (optional) fields. `_submit()`
  passes `firstName`/`lastName`. Success screen shows "Welcome, [firstName]!".

### Issue 3 — Password eye icon inverted

- **`register_screen.dart`**: Both password and confirm-password icon conditions
  corrected: `_obscureX ? Icons.visibility_off_outlined : Icons.visibility_outlined`
  (was inverted — eye-slash icon should show when password is hidden, not visible).
- **`login_screen.dart`**: Same fix for the single password field's `_obscure` condition.

---

## Files Created / Modified

### Backend
- `apps/accounts/models.py` — full_name → first_name + last_name + property
- `apps/accounts/migrations/0003_user_first_last_name.py` — NEW migration
- `apps/accounts/serializers.py` — field lists + login user dict
- `apps/accounts/views.py` — re-registration cleanup + new ordering
- `apps/accounts/admin.py` — search_fields
- `apps/accounts/management/commands/seed_demo.py` — _user() signature
- `backend/conftest.py` — _make_user()
- `apps/accounts/tests/test_auth.py`
- `apps/accounts/tests/test_email_verification.py`
- `apps/accounts/tests/test_me.py`
- `apps/accounts/tests/test_user_management.py`
- `apps/projects/tests/test_assignment_api.py`
- `apps/reports/tests/test_report_api.py`
- `apps/reports/tests/test_report_image_api.py`

### Flutter
- `mobile/lib/features/auth/models/user.dart` — firstName/lastName fields
- `mobile/lib/features/auth/auth_repository.dart` — register() signature
- `mobile/lib/features/auth/screens/register_screen.dart` — two name fields + icon fix
- `mobile/lib/features/auth/screens/login_screen.dart` — icon fix
- `mobile/lib/features/users/user_repository.dart` — ManagedUser.fromJson

---

## In Progress

Nothing in progress.

---

## Decisions Made

- `full_name` kept as a `@property` on the User model (not a DB column) for
  backwards-compatible display in serializers, admin, PDF reports, and signals —
  no other files needed updating.
- Login response now includes `first_name`, `last_name`, AND `full_name` (property)
  so Flutter can display the first name on the success screen without a second API call.
- `register()` in Flutter now returns `Future<void>` since the backend returns a
  success envelope `{"status": "success", "message": "..."}` after email verification
  was introduced — not user data.
- Demo seed users are created with `is_active=True` (override) so they can log in
  directly without email verification — appropriate for a demo environment.

---

## Known Issues / Warnings

1. **JWT key length warning** — test key < 32 bytes. Non-blocking (only in tests).
2. **`local_sqlite.py`** — not committed (gitignored). Regenerate with
   `cp backend/config/settings/test_sqlite.py backend/config/settings/local_sqlite.py`
   and set the right DB path.
3. **Verification email in dev** — printed to console (EMAIL_BACKEND = console).
   The link is `http://localhost:8000/api/v1/auth/verify-email/?token=<raw>`.

---

## Exact Next Steps

1. Run dev server + Flutter:
   ```bash
   # Backend
   cd backend && source venv/bin/activate
   DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py runserver
   # Flutter
   cd mobile && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
   ```
2. Test full registration flow:
   - Register a new user → see console email → open link → log in
   - Try re-registering with the same email → should succeed (old unverified record deleted)
   - Verify success screen shows "Welcome, [first name]!"
   - Verify password eye icons: hidden = eye-slash icon, visible = eye icon

## Commands to Re-run on Resume

```bash
# Backend tests (172 expected)
cd /Users/admin/Desktop/SmartNGO/backend
source venv/bin/activate
python -m pytest --ds=config.settings.test_sqlite -q

# Flutter
cd /Users/admin/Desktop/SmartNGO/mobile
flutter test && flutter analyze

# Dev server (SQLite)
cd /Users/admin/Desktop/SmartNGO/backend
source venv/bin/activate
DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py runserver
```

## Blockers

None.
