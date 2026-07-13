# Session Handover — 2026-07-10 | CLAUDE.md Refactor + Live Email Flow + LAN IP Fix

---

## Completed This Session

### LAN IP fix — verification links now work from phones on the same WiFi
- Problem: emails contained `http://localhost:8000/...verify-email...` links, which
  only resolve on the Mac itself. Additionally the post-verify 302 redirect pointed
  to `http://localhost:58569/#/verify-success` — same class of bug, would have
  failed on a phone even after fixing the first link.
- **`backend/.env`**: `BACKEND_BASE_URL=http://192.168.100.4:8000`,
  `FLUTTER_VERIFY_SUCCESS_URL=http://192.168.100.4:58569/#/verify-success`,
  `DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,192.168.100.4`. (Mac LAN IP from
  `ipconfig getifaddr en0` = 192.168.100.4 — re-check if WiFi network changes.)
- No code change needed: `_send_verification_email()` already builds the link from
  `settings.BACKEND_BASE_URL`, and `VerifyEmailView` already redirects to
  `settings.FLUTTER_VERIFY_SUCCESS_URL`.
- **Django** now runs `runserver 0.0.0.0:8000` (all interfaces).
- **Flutter** now runs with `--web-hostname=0.0.0.0 --web-port=58569
  --dart-define=API_BASE_URL=http://192.168.100.4:8000/api/v1` so the phone can
  load the verify-success page (dev has `CORS_ALLOW_ALL_ORIGINS=True`, so the
  IP-based API origin is fine).
- End-to-end test via LAN IP, all passing:
  - Registered `petersonmwero+lantest@gmail.com` (plus-alias → same Gmail inbox)
    → 201, email sent with the IP-based link.
  - Verify link hit via `http://192.168.100.4:8000/...` (throwaway
    `lanredirect@example.com` token) → 302 to
    `http://192.168.100.4:58569/#/verify-success`, which serves 200.
  - Login + dashboard via the IP-based API → 200; unverified account still
    correctly blocked with `EMAIL_NOT_VERIFIED`.
- Remaining manual step: click the `+lantest` email link **on the phone** (same
  WiFi) → should land on the Flutter verify-success screen.

### CLAUDE.md refactor (context-size fix)
- **`CLAUDE_RULES.md`** (NEW): Operating Rules (code quality, architecture, session
  management) + full HANDOVER.md template extracted from CLAUDE.md.
- **`CLAUDE.md`**: Shrunk from 40,819 → 33,758 chars (under the 35,000 limit).
  Raw SQL CREATE TABLE statements replaced with equivalent Django model descriptions
  (every field, choice set, FK on_delete, and constraint preserved). "What Good Looks
  Like" code-examples section removed. Pointer line to CLAUDE_RULES.md added at top.

### Full test suites re-run — all green
- **Backend: 172/172 passed** (`pytest`, `config.settings.test_sqlite`, 69s).
- **Flutter: 31/31 passed** (`flutter test`).

### Pending migration found and applied
- **`apps/accounts/migrations/0004_alter_user_first_name.py`** (NEW): leftover
  `first_name` field alteration from the first/last-name split had no migration.
  Created and applied to the local SQLite DB. **Not yet committed.**

### Live email flow — backend side verified end-to-end
- Server runs on `config.settings.local_sqlite` — **MySQL is not installed on this
  machine**, so `dev.py` settings fail with "Can't connect to MySQL server".
- `POST /api/v1/auth/register/` with `petersonmwero@gmail.com` → 201, verification
  email sent via Gmail SMTP.
- SMTP send is `fail_silently=True`, so additionally verified real Gmail SMTP
  auth explicitly: `mail.get_connection(fail_silently=False).open()` → **OK**.
- Verify link tested with a throwaway account (`verifytest@example.com`, raw token
  issued via shell since DB stores only hashes):
  - `GET /auth/verify-email/?token=…` → **302 redirect to
    `http://localhost:58569/#/verify-success`**, user flipped to `is_active=True`.
  - Token reuse → **400** (single-use enforced).
- Login gate confirmed: unverified account → `EMAIL_NOT_VERIFIED`; verified
  account logs in and `GET /analytics/dashboard/` returns role-filtered stats.
- Flutter relaunched with **`--web-port=58569`** to match `FLUTTER_VERIFY_SUCCESS_URL`
  in `backend/.env` (a random Flutter port would make the email link's redirect land
  on a dead page).

## Files Created / Modified
- `CLAUDE_RULES.md` — NEW, operating rules + HANDOVER template
- `CLAUDE.md` — shrunk to 33,758 chars
- `apps/accounts/migrations/0004_alter_user_first_name.py` — NEW migration (uncommitted)
- `HANDOVER.md` — this update

## In Progress (Partially Done)
- **Manual half of the live email test** (only Peterson can do this):
  1. Check Gmail inbox for "Verify your Smart NGO M&E Account" — **use the NEWEST
     email**; an earlier registration's token was invalidated by re-registration.
  2. Click the link → should land on the Flutter `/verify-success` screen (Flutter
     must be running on port 58569).
  3. Log in: `petersonmwero@gmail.com` / `LiveTest#2026!` (manager, Green Earth
     Initiative — set by the API test; any password typed in the browser earlier
     no longer applies because re-registration replaced that record).
  4. Confirm the manager dashboard loads.

## Decisions Made (Deviations from SDD)
- Dev server runs on `local_sqlite` settings because MySQL 8 is not installed
  locally; MySQL remains the configured DB for real dev/prod.
- Flutter web pinned to port 58569 via `--web-port` instead of editing `.env`.

## Known Issues / Warnings
1. Migration `0004_alter_user_first_name.py` needs to be committed.
2. Throwaway user `verifytest@example.com` (active, officer) exists in the local
   SQLite DB only — harmless; delete or ignore.
3. `local_sqlite.py` remains gitignored/uncommitted by design.
4. `flutter run` reports a newer Flutter version is available (non-blocking).

## Exact Next Steps (in order)
1. Peterson: complete the manual email steps above (inbox → link → success screen →
   login → dashboard).
2. Commit: `CLAUDE.md`, `CLAUDE_RULES.md`, `0004_alter_user_first_name.py`, `HANDOVER.md`.
3. If the manual flow passes, mark the email-verification feature done in PROGRESS.md.

## Commands to Re-run on Resume
```bash
# Backend tests (172 expected)
cd /Users/admin/Desktop/SmartNGO/backend && source venv/bin/activate
DJANGO_SETTINGS_MODULE=config.settings.test_sqlite pytest --tb=short -q

# Dev server (SQLite — MySQL not installed locally)
DJANGO_SETTINGS_MODULE=config.settings.local_sqlite python manage.py runserver

# Flutter — port must match FLUTTER_VERIFY_SUCCESS_URL in backend/.env
cd /Users/admin/Desktop/SmartNGO/mobile
flutter run -d chrome --web-port=58569 --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## Blockers
None.
