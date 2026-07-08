# Session Handover — 2026-07-08 | Email Verification + Registration Overhaul

---

## Completed This Session

### Email Verification Flow (Backend)

1. **New model** `EmailVerificationToken` in `apps/accounts/models.py` — SHA-256 hashed, 24-hour TTL, single-use, same pattern as PasswordResetToken.

2. **New token helpers** in `apps/accounts/tokens.py`:
   - `issue_email_verification_token(user)` — invalidates old tokens, returns raw token
   - `consume_email_verification_token(raw_token)` — returns record or None, marks expired tokens used

3. **Registration changed** (`apps/accounts/views.py` `RegisterView`):
   - `perform_create()` saves user with `is_active=False`, generates token, sends verification email
   - `create()` returns `{"status": "success", "message": "...verification email sent..."}` instead of user data
   - `_send_verification_email()` helper uses `settings.BACKEND_BASE_URL` (default: http://localhost:8000)

4. **New endpoints** added to `apps/accounts/urls.py`:
   - `GET /api/v1/auth/verify-email/?token=<raw>` — validates token, sets user.is_active=True, marks token used
   - `POST /api/v1/auth/resend-verification/` — re-sends email; always returns 200 (no enumeration)

5. **Login blocked** for unverified users in `SmartTokenObtainPairSerializer.validate()`:
   - Checks `User.objects.filter(is_active=False).filter(email_verification_tokens__used=False).exists()`
   - Raises `_EmailNotVerifiedException` (AuthenticationFailed subclass, code=`EMAIL_NOT_VERIFIED`)
   - Custom exception handler returns `{"error": "...", "code": "EMAIL_NOT_VERIFIED"}`

6. **Role restriction updated** — `SELF_REGISTRABLE_ROLES` now includes `{OFFICER, DONOR, MANAGER}` (admin still blocked). Error message updated to say "Admin accounts cannot be created through self-registration."

7. **Public NGO endpoint** (`apps/ngos/views.py`) — `@action` at `GET /api/v1/ngos/public/` returns `[{id, name}]`, no auth required, used by register screen.

8. **`BACKEND_BASE_URL` setting** added to `config/settings/base.py` (default: http://localhost:8000, override via env var in production).

9. **Migration** `apps/accounts/migrations/0002_emailverificationtoken.py` — creates `email_verification_tokens` table.

10. **Tests** — `apps/accounts/tests/test_email_verification.py` (17 new tests). Updated `test_auth.py::test_register_officer_succeeds` for new response format. **Backend total: 172 passed.**

### Registration Screen Overhaul (Flutter)

11. **`register_screen.dart`** — complete rewrite:
    - Confirm password field with inline validator ("Passwords do not match")
    - Eye icon toggles on BOTH password fields (independent state)
    - NGO dropdown via `NgoRepository.listPublic()` — loading/error/retry states
    - Role selector shows Field Officer / Project Manager / Donor (no Admin)
    - Role helper text below dropdown, changes per role
    - On success: shows `_SuccessScreen` with green checkmark, email, "Back to Login" button
    - Does NOT navigate to dashboard on success

12. **`login_screen.dart`** — handles `EMAIL_NOT_VERIFIED` error code:
    - `_showResend` state flag set on `auth.errorCode == 'EMAIL_NOT_VERIFIED'`
    - "Resend verification email" `TextButton.icon` appears below Sign in button
    - Clicking resend calls `AuthRepository.resendVerification(email)` and shows snackbar

13. **`auth_provider.dart`** — added `errorCode` field alongside `error`; set/cleared in `login()`

14. **`auth_repository.dart`** — added `resendVerification(email)` method

15. **`ngo_repository.dart`** — added `NgoPublic` class (id, name) and `listPublic()` method calling `/ngos/public/`

16. **`api_client.dart`** — added `/auth/verify-email/`, `/auth/resend-verification/`, `/ngos/public/` to `_publicPaths` (skip token/refresh)

17. **`theme.dart`** — added `AppColors.charcoal`, `AppColors.success`, `AppColors.error`

18. **`flutter analyze`**: 0 issues. **`flutter test`**: 31/31 passed.

---

## Files Created / Modified

### Backend
- `apps/accounts/models.py` — EmailVerificationToken model added
- `apps/accounts/tokens.py` — issue_email_verification_token, consume_email_verification_token
- `apps/accounts/serializers.py` — SELF_REGISTRABLE_ROLES + MANAGER, _EmailNotVerifiedException, login check
- `apps/accounts/views.py` — RegisterView overrides, VerifyEmailView, ResendVerificationView
- `apps/accounts/urls.py` — verify-email/, resend-verification/
- `apps/ngos/views.py` — public_list @action
- `config/settings/base.py` — BACKEND_BASE_URL setting
- `apps/accounts/tests/test_auth.py` — test_register_officer_succeeds updated
- `apps/accounts/tests/test_email_verification.py` — NEW (17 tests)
- `apps/accounts/migrations/0002_emailverificationtoken.py` — NEW migration

### Flutter
- `mobile/lib/features/auth/screens/register_screen.dart` — full rewrite
- `mobile/lib/features/auth/screens/login_screen.dart` — EMAIL_NOT_VERIFIED handling + resend
- `mobile/lib/features/auth/auth_provider.dart` — errorCode field
- `mobile/lib/features/auth/auth_repository.dart` — resendVerification()
- `mobile/lib/features/ngos/ngo_repository.dart` — NgoPublic + listPublic()
- `mobile/lib/core/api_client.dart` — public paths updated
- `mobile/lib/core/theme.dart` — AppColors.charcoal/success/error added

---

## In Progress

Nothing in progress.

---

## Decisions Made

- Used `email_verification_tokens__used=False` (FK filter) in login to distinguish unverified users from admin-deactivated users who have no tokens. This correctly handles: (a) self-registered unverified → EMAIL_NOT_VERIFIED, (b) admin-deactivated verified user → generic 401, (c) admin-created user → no token → generic 401.
- `manager` role added to self-registrable roles (Flutter shows "Project Manager" option). Admin remains the only blocked role.
- Resend verification endpoint always returns 200 (prevents user enumeration).

---

## Known Issues / Warnings

1. **JWT key length warning** — same as before (test key < 32 bytes). Non-blocking.
2. **`local_sqlite.py`** — not committed to git (gitignored). Regenerate with `cp backend/config/settings/test_sqlite.py backend/config/settings/local_sqlite.py` and adjust path if needed.
3. **Verification email in dev** — printed to console (EMAIL_BACKEND = console). The link is `http://localhost:8000/api/v1/auth/verify-email/?token=<raw>`. Open it in the browser to verify.

---

## Exact Next Steps

1. Test the full flow in the browser:
   - Register a new user → see console email → open link → log in
   - Try logging in before verifying → see "Resend" button
   - Try reusing the same token → see 400 error
2. Commit changes: `git add -A && git commit -m "feat: email verification flow + register screen overhaul"`

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
