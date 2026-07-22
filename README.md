# Smart NGO — Monitoring & Evaluation

A full-stack NGO project management and M&E (Monitoring & Evaluation) system: a
**Django REST** backend and a **Flutter** mobile/web client. Built as a Software
Engineering senior project at the University of Eastern Africa, Baraton.

NGOs manage projects, assign field officers, register beneficiaries, capture
field reports (with GPS and photos), track indicators and milestones, and share
read-only progress with donors — with role-based access enforced server-side.

---

## Status

All five build phases are complete and the app is demo-ready. The post-phase
enhancements are landed too: structured donor reporting (with a PDF impact
report), a six-month reporting-trend chart, admin user editing,
constituency-scoped Kenya location data, and a fully clean OpenAPI schema.

**257 backend tests / 77 Flutter tests pass**, `flutter analyze` reports 0
issues, and the OpenAPI schema validates with 0 warnings / 0 errors. The backlog
is empty — remaining ideas would be new scope.

---

## Architecture

```
┌─────────────────┐     HTTPS / REST (JSON)      ┌──────────────────┐        ┌──────────┐
│  Flutter client │  ◀──────────────────────▶    │  Django REST API │  ◀──▶  │ MySQL 8  │
│  (web / mobile) │     JWT Bearer auth          │  /api/v1/        │        │          │
└─────────────────┘                              └──────────────────┘        └──────────┘
```

Three-tier, stateless API, versioned under `/api/v1/`. Every authenticated
request carries a JWT access token; role-based access control is enforced in the
API (never trusted from the client).

## Tech stack

| Layer | Technology |
|-------|------------|
| Mobile/Web | Flutter 3.44 / Dart · Dio · flutter_secure_storage · geolocator · image_picker · provider · go_router · fl_chart · shimmer |
| Backend | Python · Django 4.2 LTS · Django REST Framework |
| Auth | djangorestframework-simplejwt (15-min access / 7-day refresh, blacklist on logout) |
| Database | MySQL 8 (via PyMySQL driver) |
| API docs | drf-spectacular (Swagger UI at `/api/v1/docs/`) |
| PDF | ReportLab |
| Tests | pytest + pytest-django (backend) · flutter_test (mobile) |

> **Note:** The backend targets **Django 4.2 LTS** because the development
> machine runs Python 3.9. MySQL 8 remains the configured database; the
> pure-Python **PyMySQL** driver is used so no native build tools are required.

## Roles & permissions

| Role | Capabilities |
|------|--------------|
| **admin** | Full CRUD on everything; manages NGOs and users |
| **manager** | Full CRUD on their own NGO's projects; assigns officers; approves reports |
| **officer** | Submits reports, registers beneficiaries; read access to assigned projects |
| **donor** | Read-only access to their NGO's projects and reports (incl. PDF summaries) |

Self-registration is limited to `officer` / `donor`; admin and manager accounts
are provisioned by an administrator.

---

## Project layout

```
SmartNGO/
├── backend/                 # Django REST API
│   ├── config/              # project: settings/{base,dev,prod,test_sqlite}, urls, api_router
│   ├── apps/
│   │   ├── accounts/        # custom User, JWT auth, password reset, permissions
│   │   ├── ngos/            # NGOs
│   │   ├── projects/        # projects, assignments, milestones, PDF actions, cron command
│   │   ├── indicators/      # KPI indicators
│   │   ├── beneficiaries/   # beneficiaries (soft-delete, computed age)
│   │   ├── reports/         # reports workflow + image upload
│   │   ├── notifications/   # notifications + signals
│   │   └── common/          # shared mixins, PDF builders
│   ├── requirements.txt
│   └── .env.example
└── mobile/                  # Flutter client (feature-based)
    └── lib/
        ├── core/            # config, Dio client + JWT interceptor, token storage, theme, GoRouter
        └── features/        # auth, dashboard, projects, reports, beneficiaries,
                             # notifications, analytics, users, ngos, splash
```

---

## Backend setup

Requires **Python 3.9+** and a running **MySQL 8** server.

```bash
cd backend

# 1. Virtual environment + dependencies
python3 -m venv venv
./venv/bin/python -m pip install -r requirements.txt

# 2. Configure environment
cp .env.example .env          # then edit: DB creds + a long DJANGO_SECRET_KEY

# 3. Create the database (once)
mysql -u root -e "CREATE DATABASE smartngo CHARACTER SET utf8mb4;"

# 4. Migrate + create the first admin
#    (createsuperuser auto-attaches a bootstrap "System NGO" since users.ngo_id is NOT NULL)
./venv/bin/python manage.py migrate
./venv/bin/python manage.py createsuperuser

# (optional) load demo data: NGOs, a user per role, projects, reports, etc.
#   prints demo logins; password for all seeded users is DemoPass123!
./venv/bin/python manage.py seed_demo

# 5. Run
./venv/bin/python manage.py runserver
```

- API base: `http://localhost:8000/api/v1/`
- Swagger UI: `http://localhost:8000/api/v1/docs/`
- Django admin: `http://localhost:8000/admin/`

### Environment variables (`backend/.env`)

```
DJANGO_SECRET_KEY=<long-random-string>
DJANGO_DEBUG=true
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DB_NAME=smartngo
DB_USER=root
DB_PASSWORD=
DB_HOST=127.0.0.1
DB_PORT=3306
```

Settings modules: `config.settings.dev` (default), `config.settings.prod`
(HTTPS/HSTS hardening), `config.settings.test_sqlite` (tests, in-memory SQLite).

### Scheduled job — milestone reminders

Signals can't fire on a future date, so the "milestone due in 3 days" reminder
is a management command. Run it daily via cron:

```cron
0 7 * * *  cd /path/to/backend && venv/bin/python manage.py notify_due_milestones
```

It notifies each project's team of milestones due in N days (`--days`, default 3)
and flags pending past-due milestones as `overdue`.

---

## Mobile / web setup

Requires the **Flutter SDK** (3.44+). The web target needs only Chrome; Android
or iOS additionally need the Android SDK or Xcode.

```bash
cd mobile
flutter pub get

# Run against a local backend (web)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

The `API_BASE_URL` default is `http://localhost:8000/api/v1`. For an Android
emulator hitting a local backend, use `http://10.0.2.2:8000/api/v1`.

Build a release web bundle:

```bash
flutter build web
```

### Implemented screens (17)

Splash · Login · Register · Forgot Password · Dashboard · Projects list · Project detail (4 tabs) · Create Project (3-step form) · Submit Report (GPS + photos) · Reports list · Report Detail (photo gallery + approve) · Beneficiary list · Register Beneficiary · Notifications · Profile · User Management (admin) · NGO Management (admin) · Analytics Dashboard (fl_chart)

Navigation uses **GoRouter** with role-based redirect guards. Admin-only routes (`/users`, `/ngos`) redirect non-admin users to the dashboard.

---

## API overview

All routes are under `/api/v1/`. List endpoints are paginated
(`{count, next, previous, results}`), support filters (e.g. `?status=active`,
`?project_id=3`), and errors use a consistent `{ "error": ..., "code": ... }`
envelope.

| Resource | Endpoints |
|----------|-----------|
| Auth | `register/`, `login/`, `logout/`, `token/refresh/`, `me/`, `password-reset/`, `password-reset/confirm/` |
| NGOs | `ngos/` (admin only) |
| Projects | `projects/` + `projects/{id}/assignments/` |
| Beneficiaries | `beneficiaries/`, `beneficiaries/export/` (CSV) |
| Indicators | `indicators/` |
| Milestones | `milestones/` |
| Reports | `reports/`, `reports/{id}/submit/`, `reports/{id}/approve/`, `reports/{id}/images/` |
| Notifications | `notifications/`, `notifications/mark-all-read/` |
| Users | `users/`, `users/{id}/toggle-active/` (admin only) |
| Analytics | `analytics/dashboard/` (role-filtered KPIs) |
| PDFs | `projects/{id}/summary-pdf/`, `projects/{id}/monthly-report/?year=&month=` |

Report workflow: **draft → submitted → approved** (author submits; manager/admin
approves; edits locked once submitted).

See the live Swagger UI for full request/response schemas.

---

## Security

- Passwords hashed with **BCryptSHA256**; minimum length 8 enforced.
- **JWT**: 15-minute access tokens, 7-day refresh tokens, blacklisted on logout;
  the client auto-refreshes on 401 and retries transparently.
- **Throttling**: 20 req/min anonymous, 100 req/min authenticated.
- **Role permission classes** applied to every viewset; querysets are
  NGO-scoped so users only see their own organisation's data.
- **File uploads** validated for image MIME type and a 5 MB cap.
- **Password-reset tokens** are SHA-256-hashed, single-use, and expire in 1 hour;
  the request endpoint never reveals whether an email is registered.
- Production settings enforce HTTPS, HSTS, and secure cookies.

---

## Testing

```bash
# Backend (257 tests) — locally on in-memory SQLite, no MySQL needed
cd backend && ./venv/bin/python -m pytest --ds=config.settings.test_sqlite

# Mobile (77 tests) + static analysis (0 issues)
cd mobile && flutter test && flutter analyze
```

Coverage includes every endpoint, all four role permission classes, the report
and password-reset workflows, notification signals, the cron command, the Dio
JWT-refresh interceptor, and a dedicated security-boundary suite
(cross-role denials, token expiry, refresh blacklisting, rate limiting).

CI (GitHub Actions) runs the backend suite against a real **MySQL 8** service
(`config.settings.ci`) and the mobile suite via `flutter analyze` + `flutter test`.

---

## Database schema (11 core tables)

`users` · `ngos` · `projects` · `project_assignments` · `beneficiaries` ·
`reports` · `report_images` · `indicators` · `milestones` · `notifications` ·
`password_reset_tokens`

Key rules: `users.ngo_id` and `projects.ngo_id` are `NOT NULL`; `reports.officer`
uses `PROTECT` (a report keeps its author even after the officer leaves the
project); `users` and `beneficiaries` use soft-delete (`is_active`).

---

## License

Academic project — University of Eastern Africa, Baraton.
