# SMART NGO M&E MOBILE APPLICATION
## Claude Code Master Build Prompt
### Author: Peterson Ruwa | University of Eastern Africa, Baraton
### Supervisor: Mr. Jefferson Mwatati

---

## ⚠️ CRITICAL: READ THIS ENTIRE PROMPT BEFORE WRITING A SINGLE LINE OF CODE

This is a senior software engineering project. Every decision you make must
reflect production-quality standards. You are not building a prototype. You
are building a system that will be assessed by a university supervisor and
must demonstrate mastery of software engineering principles.

---

## OPERATING RULES (Non-negotiable — follow these throughout every session)

### Code Quality Rules
- Write code as a senior engineer would: clean, readable, commented, structured
- Every function/method must have a docstring explaining what it does
- No magic numbers — use named constants or enums
- No TODO comments left in committed code — either implement it or document it in HANDOVER.md
- DRY principle: never repeat logic — extract shared logic into utilities/mixins/helpers
- Validate ALL inputs server-side, regardless of what the Flutter client sends
- Handle ALL edge cases explicitly — never assume happy path only
- Every API endpoint must have error handling for: missing fields, wrong types,
  unauthorized access, not-found, and server errors

### Architecture Rules
- Never mix business logic into views/serializers — use service layer functions
- Never put raw SQL in views — use the ORM exclusively
- Never hardcode secrets, URLs, or environment-specific values — use .env and settings
- Never trust the client for permissions — enforce RBAC on every single endpoint server-side
- Separate concerns strictly: models handle data, serializers handle validation/shape,
  views handle HTTP, services handle business logic

### Session Management Rules
- At the start of every session: read HANDOVER.md and PROGRESS.md if they exist
- At the end of every session (or when context is running low): update HANDOVER.md
- After completing each phase: update PROGRESS.md with what is done and what is next
- Before any phase transition: stop and confirm with the user
- If you encounter a blocker, document it in HANDOVER.md under "Blockers"
  and propose 2-3 solutions before picking one

### HANDOVER.md Template (write this at end of every session)
```
# Session Handover — [Date] [Session Number]

## Completed This Session
- [Specific file/feature, not vague: "Created accounts/models.py with CustomUser model
  including ngo_id FK and role enum field" not "worked on models"]

## Files Created/Modified
- [List every file touched with a one-line description]

## In Progress (Partially Done)
- [What was started but not finished — exact stopping point]

## Decisions Made (Deviations from SDD)
- [Any deviation from spec with reason — if none, write "None"]

## Known Issues / Warnings
- [Any errors, deprecation warnings, or lint issues not yet resolved]

## Exact Next Steps (in order)
1. [First thing to do next session]
2. [Second thing]
3. ...

## Commands to Re-run on Resume
- [e.g., "Run python manage.py makemigrations accounts after pulling"]

## Blockers
- [Anything blocking progress — or "None"]
```

---

## PROJECT IDENTITY

- **Project**: Smart NGO Monitoring and Evaluation Mobile Application
- **Author**: Peterson Ruwa
- **Institution**: University of Eastern Africa, Baraton
- **Supervisor**: Mr. Jefferson Mwatati
- **Programme**: BSc Software Engineering
- **Stack**: Flutter (mobile) + Django REST Framework (backend) + MySQL 8 (database)

---

## TECHNOLOGY STACK (Fixed — do not substitute without asking first)

### Backend
| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Python | 3.12 |
| Framework | Django | 5.x |
| API | Django REST Framework | 3.15.x |
| Auth | djangorestframework-simplejwt | 5.x |
| Password | BCryptSHA256PasswordHasher | Django built-in |
| Database | MySQL | 8.x |
| API Docs | drf-spectacular + Swagger UI | 0.27.x |
| PDF | ReportLab | Latest |
| Testing | pytest + pytest-django | 8.x |
| Env vars | python-decouple | Latest |
| CORS | django-cors-headers | Latest |

### Mobile (Flutter)
| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Dart | 3.x |
| Framework | Flutter | 3.x |
| HTTP | Dio | 5.x |
| Token storage | flutter_secure_storage | 9.x |
| GPS | geolocator | 11.x |
| Images | image_picker | 1.x |
| State management | Provider or Riverpod | Latest |
| Navigation | GoRouter | Latest |
| Local DB (drafts) | sqflite | Latest |
| Charts | fl_chart | Latest |

---

## REPOSITORY STRUCTURE

Create this exact folder structure before writing any code:

```
SmartNGO/
├── backend/
│   ├── config/                    # Django project settings
│   │   ├── __init__.py
│   │   ├── settings/
│   │   │   ├── __init__.py
│   │   │   ├── base.py            # Shared settings
│   │   │   ├── development.py     # Dev overrides
│   │   │   └── production.py      # Prod overrides
│   │   ├── urls.py
│   │   ├── wsgi.py
│   │   └── asgi.py
│   ├── apps/
│   │   ├── accounts/              # Users, auth, JWT
│   │   │   ├── models.py
│   │   │   ├── serializers.py
│   │   │   ├── views.py
│   │   │   ├── urls.py
│   │   │   ├── permissions.py     # Custom RBAC classes
│   │   │   ├── services.py        # Business logic
│   │   │   └── tests/
│   │   │       ├── test_models.py
│   │   │       ├── test_views.py
│   │   │       └── test_permissions.py
│   │   ├── ngos/
│   │   ├── projects/
│   │   ├── beneficiaries/
│   │   ├── reports/
│   │   ├── indicators/
│   │   ├── milestones/
│   │   └── notifications/
│   ├── core/
│   │   ├── exceptions.py          # Global exception handler
│   │   ├── pagination.py          # Standard paginator
│   │   ├── responses.py           # Standard response wrapper
│   │   └── utils.py               # Shared utilities
│   ├── requirements/
│   │   ├── base.txt
│   │   ├── development.txt
│   │   └── production.txt
│   ├── .env.example               # Template — never commit real .env
│   ├── manage.py
│   └── pytest.ini
│
├── mobile/
│   └── smart_ngo/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app.dart            # App root, router setup
│       │   ├── core/
│       │   │   ├── constants/      # Colors, strings, endpoints
│       │   │   ├── errors/         # Failure classes
│       │   │   ├── network/        # Dio client, interceptors
│       │   │   ├── storage/        # SecureStorage wrapper
│       │   │   └── utils/          # Helpers
│       │   └── features/
│       │       ├── auth/
│       │       │   ├── data/       # API calls, models
│       │       │   ├── domain/     # Use cases, entities
│       │       │   └── presentation/ # Screens, widgets, providers
│       │       ├── dashboard/
│       │       ├── projects/
│       │       ├── reports/
│       │       ├── beneficiaries/
│       │       ├── indicators/
│       │       ├── milestones/
│       │       └── notifications/
│       ├── test/
│       └── pubspec.yaml
│
├── HANDOVER.md                    # Updated every session
├── PROGRESS.md                    # Phase-level progress tracker
├── DECISIONS.md                   # Architectural decisions log
└── README.md                      # Setup instructions
```

---

## DATABASE SCHEMA (Implement exactly — no deviations without asking)

### Table 1: ngos
```sql
CREATE TABLE ngos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    registration_no VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    address VARCHAR(500),
    contact VARCHAR(100),
    logo VARCHAR(500),
    created_at DATETIME DEFAULT NOW()
);
```

### Table 2: users (Custom Django User Model)
```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,   -- login credential, NOT username
    password VARCHAR(255) NOT NULL,        -- bcrypt hashed, NEVER plaintext
    role ENUM('admin','manager','officer','donor') NOT NULL,
    phone VARCHAR(20),
    ngo_id INT NOT NULL,                   -- FK → ngos.id, multi-tenant isolation
    is_active BOOLEAN DEFAULT TRUE,        -- soft delete
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (ngo_id) REFERENCES ngos(id) ON DELETE RESTRICT
);
```

### Table 3: projects
```sql
CREATE TABLE projects (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_name VARCHAR(255) NOT NULL,
    description TEXT,
    budget DECIMAL(15,2) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status ENUM('planning','active','on_hold','completed','cancelled') NOT NULL DEFAULT 'planning',
    ngo_id INT NOT NULL,                   -- NOT NULL: orphan projects not permitted
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (ngo_id) REFERENCES ngos(id) ON DELETE RESTRICT
);
```

### Table 4: project_assignments
```sql
CREATE TABLE project_assignments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('manager','officer') NOT NULL,
    assigned_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    UNIQUE KEY unique_assignment (project_id, user_id)  -- no duplicate assignments
);
```

### Table 5: beneficiaries
```sql
CREATE TABLE beneficiaries (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    gender ENUM('male','female','other') NOT NULL,
    date_of_birth DATE NOT NULL,           -- NEVER a static age INT
    phone VARCHAR(20),
    location VARCHAR(255),
    project_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,        -- soft delete
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT
);
```

### Table 6: reports
```sql
CREATE TABLE reports (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    officer_id INT NOT NULL,               -- preserved on officer removal from project
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    gps_latitude DECIMAL(10,7),
    gps_longitude DECIMAL(10,7),
    report_type ENUM('daily','weekly','monthly') NOT NULL,
    status ENUM('draft','submitted','approved') NOT NULL DEFAULT 'draft',
    date_submitted DATETIME DEFAULT NOW(),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT,
    FOREIGN KEY (officer_id) REFERENCES users(id) ON DELETE RESTRICT
    -- ON DELETE RESTRICT on officer_id: reports must survive officer removal
);
```

### Table 7: report_images
```sql
CREATE TABLE report_images (
    id INT PRIMARY KEY AUTO_INCREMENT,
    report_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    caption VARCHAR(255),
    uploaded_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE
);
```

### Table 8: indicators
```sql
CREATE TABLE indicators (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    indicator_name VARCHAR(255) NOT NULL,
    target_value DECIMAL(15,2) NOT NULL,
    current_value DECIMAL(15,2) DEFAULT 0.00,
    unit VARCHAR(50),
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);
```

### Table 9: milestones
```sql
CREATE TABLE milestones (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date DATE NOT NULL,
    status ENUM('pending','completed','overdue') NOT NULL DEFAULT 'pending',
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);
```

### Table 10: notifications
```sql
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status ENUM('unread','read') NOT NULL DEFAULT 'unread',
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Table 11: password_reset_tokens
```sql
CREATE TABLE password_reset_tokens (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,    -- SHA-256 hashed token
    expires_at DATETIME NOT NULL,          -- 1 hour from creation
    used BOOLEAN DEFAULT FALSE,            -- single-use: set TRUE on first use
    created_at DATETIME DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Database Indexes (add these after creating tables)
```sql
-- All FK columns must be indexed for JOIN performance
CREATE INDEX idx_users_ngo_id ON users(ngo_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_projects_ngo_id ON projects(ngo_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_assignments_project ON project_assignments(project_id);
CREATE INDEX idx_assignments_user ON project_assignments(user_id);
CREATE INDEX idx_beneficiaries_project ON beneficiaries(project_id);
CREATE INDEX idx_reports_project ON reports(project_id);
CREATE INDEX idx_reports_officer ON reports(officer_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_report_images_report ON report_images(report_id);
CREATE INDEX idx_indicators_project ON indicators(project_id);
CREATE INDEX idx_milestones_project ON milestones(project_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(status);
```

---

## API SPECIFICATION

### Base URL: /api/v1/
### All responses must follow this envelope:
```json
// Success
{"status": "success", "data": {...}, "message": "Human readable message"}

// Error
{"status": "error", "code": "SPECIFIC_ERROR_CODE", "message": "Human readable error"}

// Paginated list
{"status": "success", "count": 100, "next": "url", "previous": null, "results": [...]}
```

### Endpoint Groups

#### Auth: /api/v1/auth/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| POST | /auth/register/ | Public | Register user, return tokens |
| POST | /auth/login/ | Public | Login, return access+refresh tokens |
| POST | /auth/logout/ | Auth | Blacklist refresh token |
| POST | /auth/token/refresh/ | Public | Get new access token |
| POST | /auth/password-reset/ | Public | Send reset email |
| POST | /auth/password-reset/confirm/ | Public | Confirm token + set new password |
| GET | /auth/me/ | Auth | Get current user profile |

#### Projects: /api/v1/projects/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /projects/ | Auth | Paginated list, filter ?status=&ngo_id= |
| POST | /projects/ | Manager/Admin | Create project |
| GET | /projects/{id}/ | Auth | Project detail |
| PUT | /projects/{id}/ | Manager/Admin | Full update |
| PATCH | /projects/{id}/ | Manager/Admin | Partial update |
| DELETE | /projects/{id}/ | Admin | Soft delete |
| GET | /projects/{id}/assignments/ | Manager/Admin | List assigned users |
| POST | /projects/{id}/assignments/ | Manager/Admin | Assign user to project |
| DELETE | /projects/{id}/assignments/{uid}/ | Manager/Admin | Remove user from project |
| GET | /projects/{id}/milestones/ | Auth | List project milestones |
| GET | /projects/{id}/indicators/ | Auth | List project indicators |
| GET | /projects/{id}/reports/ | Auth | List project reports |

#### Beneficiaries: /api/v1/beneficiaries/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /beneficiaries/ | Auth | Paginated, filter ?project_id=&gender=&is_active= |
| POST | /beneficiaries/ | Officer/Manager/Admin | Register |
| GET | /beneficiaries/{id}/ | Auth | Detail (includes computed age) |
| PUT | /beneficiaries/{id}/ | Officer/Manager/Admin | Update |
| PATCH | /beneficiaries/{id}/ | Officer/Manager/Admin | Partial update |
| DELETE | /beneficiaries/{id}/ | Manager/Admin | Soft delete (is_active=False) |
| GET | /beneficiaries/export/ | Manager/Admin | CSV export |

#### Reports: /api/v1/reports/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /reports/ | Auth | Paginated, filter ?project_id=&status=&officer_id= |
| POST | /reports/ | Officer/Manager/Admin | Create (status=draft) |
| GET | /reports/{id}/ | Auth | Detail with images |
| PUT | /reports/{id}/ | Officer (own+draft only) | Full update |
| PATCH | /reports/{id}/ | Officer/Manager | Partial; Manager can approve |
| DELETE | /reports/{id}/ | Manager/Admin | Delete |
| POST | /reports/{id}/images/ | Officer/Manager | Upload images (multipart, max 5) |
| DELETE | /reports/{id}/images/{img_id}/ | Officer/Manager | Remove image |

#### Indicators: /api/v1/indicators/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /indicators/ | Auth | List, filter ?project_id= |
| POST | /indicators/ | Manager/Admin | Create |
| GET | /indicators/{id}/ | Auth | Detail with % progress |
| PUT | /indicators/{id}/ | Manager/Admin | Update |
| PATCH | /indicators/{id}/ | Manager/Admin | Partial update |
| DELETE | /indicators/{id}/ | Manager/Admin | Delete |

#### Milestones: /api/v1/milestones/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /milestones/ | Auth | List, filter ?project_id=&status= |
| POST | /milestones/ | Manager/Admin | Create |
| GET | /milestones/{id}/ | Auth | Detail |
| PUT | /milestones/{id}/ | Manager/Admin | Update |
| PATCH | /milestones/{id}/ | Manager/Admin | Partial update |
| DELETE | /milestones/{id}/ | Manager/Admin | Delete |

#### NGOs: /api/v1/ngos/ (Admin only)
| Method | Endpoint | Access |
|--------|----------|--------|
| GET/POST | /ngos/ | Admin |
| GET/PUT/PATCH/DELETE | /ngos/{id}/ | Admin |

#### Notifications: /api/v1/notifications/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /notifications/ | Auth | User's own notifications, filter ?status=unread |
| PATCH | /notifications/{id}/ | Auth | Mark as read |
| DELETE | /notifications/{id}/ | Auth | Delete |
| POST | /notifications/mark-all-read/ | Auth | Mark all unread as read |

#### Users: /api/v1/users/ (Admin only)
| Method | Endpoint | Access |
|--------|----------|--------|
| GET/POST | /users/ | Admin |
| GET/PUT/PATCH | /users/{id}/ | Admin |
| PATCH | /users/{id}/deactivate/ | Admin |

#### Analytics: /api/v1/analytics/
| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| GET | /analytics/dashboard/ | Auth | Role-filtered dashboard stats |
| GET | /analytics/projects/{id}/report/ | Manager/Admin | PDF project report |
| GET | /analytics/donor-report/{project_id}/ | Donor/Admin | Donor PDF summary |

---

## SECURITY REQUIREMENTS (All mandatory — no shortcuts)

### Password Security
```python
# settings/base.py
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.BCryptSHA256PasswordHasher',
]
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
     'OPTIONS': {'min_length': 8}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
```

### JWT Configuration
```python
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'ALGORITHM': 'HS256',
    'AUTH_HEADER_TYPES': ('Bearer',),
}
```

### Rate Limiting
```python
REST_FRAMEWORK = {
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '20/minute',
        'user': '100/minute',
    },
}
```

### Custom Permission Classes (implement all 5)
```python
# apps/accounts/permissions.py

class IsNGOAdmin(BasePermission):
    """User is authenticated and has admin role."""

class IsProjectManager(BasePermission):
    """User is authenticated and has manager role."""

class IsFieldOfficer(BasePermission):
    """User is authenticated and has officer role."""

class IsDonor(BasePermission):
    """User is authenticated and has donor role."""

class IsManagerOrAdmin(BasePermission):
    """User is authenticated and has manager or admin role."""

class IsOfficerManagerOrAdmin(BasePermission):
    """User is authenticated and has officer, manager, or admin role."""
```

### File Upload Validation
```python
ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp']
MAX_IMAGE_SIZE_MB = 5
MAX_IMAGES_PER_REPORT = 5
```

---

## BUSINESS LOGIC RULES (Implement all of these — they will be tested)

1. **Multi-tenant isolation**: Users can only see data belonging to their NGO.
   Never return data from other NGOs, even for admins of one NGO.
   System-wide admin (role='admin') can see all NGOs.

2. **Officer removal**: When removing an officer from a project via
   DELETE /projects/{id}/assignments/{uid}/, their submitted reports must
   be preserved. officer_id on reports is never nullified or deleted.
   Create a notification to the officer informing them of removal.

3. **Report workflow**: 
   - Only the submitting officer (or manager/admin) can edit a DRAFT report
   - Once SUBMITTED, only manager/admin can update it
   - Once APPROVED, no one can edit it (return 403 with clear message)
   - Only manager/admin can change status from submitted → approved
   
4. **Milestone auto-overdue**: When listing or retrieving milestones,
   auto-update status to 'overdue' if due_date < today and status == 'pending'.
   Do this in the serializer's to_representation() method.

5. **Beneficiary age**: Never store age. Compute it dynamically:
   ```python
   from datetime import date
   def compute_age(date_of_birth):
       today = date.today()
       return today.year - date_of_birth.year - (
           (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
       )
   ```
   Include 'age' as a computed read-only field in BeneficiarySerializer.

6. **Indicator progress**: Include 'progress_percentage' as a computed
   read-only field: round((current_value / target_value) * 100, 1)
   Handle target_value = 0 to avoid division by zero.

7. **Password reset token**: 
   - Generate a cryptographically secure random token (secrets.token_urlsafe(32))
   - Store SHA-256 hash of the token in the DB, send plaintext in the email
   - Expire after 60 minutes
   - Mark used=True on first use; reject any reuse with 400 + clear error

8. **Dashboard stats** (role-filtered):
   - Admin: total NGOs, total projects, total beneficiaries, total reports
   - Manager: own projects count by status, total beneficiaries, pending reports
   - Officer: assigned projects, reports submitted this month, reports pending approval
   - Donor: funded projects, total beneficiaries reached, approved reports count

9. **Notifications** (create via Django signals):
   - `post_save` on ProjectAssignment → notify assigned user
   - Daily cron / management command → notify managers of milestones due in 3 days
   - `post_save` on Report (status=approved) → notify submitting officer
   - `post_delete` on ProjectAssignment → notify removed officer

---

## FLUTTER APP REQUIREMENTS

### Architecture: Feature-Based Clean Architecture
```
features/auth/
    data/
        datasources/auth_remote_datasource.dart  # Dio API calls
        models/user_model.dart                   # JSON parsing
        repositories/auth_repository_impl.dart   # Implements domain contract
    domain/
        entities/user.dart                       # Pure Dart class, no Flutter deps
        repositories/auth_repository.dart        # Abstract interface
        usecases/login_usecase.dart
        usecases/register_usecase.dart
    presentation/
        providers/auth_provider.dart             # State management
        screens/login_screen.dart
        screens/register_screen.dart
        widgets/role_selector_widget.dart
```

### Dio Client with JWT Interceptor
```dart
// Must implement:
// 1. Attach access token to every request
// 2. On 401: auto-refresh using refresh token
// 3. On refresh failure: clear tokens, redirect to login
// 4. Retry original request after successful refresh
// 5. Handle network errors gracefully (no unhandled exceptions)
```

### Design System (Implement as constants — never hardcode colors/fonts)
```dart
// core/constants/app_colors.dart
class AppColors {
  static const Color primary = Color(0xFF0D4A2F);      // Forest Green
  static const Color primaryMid = Color(0xFF1A6B45);
  static const Color accent = Color(0xFFE8A020);        // Savannah Amber
  static const Color accentLight = Color(0xFFFFC84A);
  static const Color sage = Color(0xFF7BAF7A);
  static const Color sageLt = Color(0xFFC2DCC2);
  static const Color background = Color(0xFFF7F5F0);   // Warm Cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF1C1C1E);
  static const Color greyDark = Color(0xFF3A3A3C);
  static const Color greyMid = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFFD1D5DB);
  static const Color success = Color(0xFF166534);
  static const Color warning = Color(0xFF92400E);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF1D4ED8);
}

// core/constants/app_text_styles.dart
class AppTextStyles {
  static const String displayFont = 'SpaceGrotesk';
  static const String bodyFont = 'Inter';
  // Define TextStyle instances for: h1, h2, h3, body, caption, label
}

// core/constants/app_dimensions.dart
class AppDimensions {
  static const double radiusCard = 18.0;
  static const double radiusInput = 10.0;
  static const double buttonHeight = 50.0;
  static const double inputHeight = 46.0;
  static const double bottomNavHeight = 62.0;
  static const double minTouchTarget = 44.0;
  static const double paddingPage = 16.0;
  static const double paddingCard = 16.0;
}
```

### Required Screens (17 total — implement all)
1. Splash screen with app logo and animated transition
2. Login screen (email, password, role selector chips, forgot password link)
3. Forgot Password screen
4. Dashboard (role-aware KPI cards, project list, activity feed, FAB)
5. Project List (search, filter chips by status, project cards with progress)
6. Project Detail (4 tabs: Overview, Milestones, Team, KPIs)
7. Create/Edit Project (multi-step form)
8. Submit Report (step indicator, GPS capture, multi-photo upload)
9. Report List (filter by status, project)
10. Report Detail (photo gallery, GPS display, approve button for manager)
11. Beneficiary List (search, filters, stats row)
12. Register Beneficiary (form with DOB picker, project selector)
13. Notifications (unread badge on nav, tap to mark read)
14. Profile (avatar, role badge, change password, logout)
15. User Management (Admin only)
16. NGO Management (Admin only)
17. Analytics Dashboard (charts using fl_chart)

### UI Rules
- Every list screen must show a loading shimmer (not a spinner) while fetching
- Every form must show inline validation errors on field blur, not just on submit
- Empty states must be designed (not blank screens): icon + message + CTA button
- Pull-to-refresh on all list screens
- Error snackbars with retry action for network errors
- All images must have error fallback placeholder
- All tappable elements minimum 44px height (Flutter Material default = 48px ✓)

---

## TESTING REQUIREMENTS

### Backend — Required Test Coverage
Every app must have tests for:
- **Models**: field constraints, string representation, custom methods
- **Serializers**: valid data, invalid data, edge cases, computed fields
- **Views/Endpoints**: for each endpoint test:
  - Happy path (correct data, correct role)
  - Authentication required (401 if no token)
  - Role enforcement (403 for wrong role)
  - Not found (404 for invalid ID)
  - Validation error (400 for bad input)
- **Permissions**: test each custom permission class in isolation
- **Business logic**: service functions tested in isolation

### Pytest Configuration
```ini
# pytest.ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.development
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short --strict-markers
markers =
    unit: Unit tests (fast, no DB)
    integration: Integration tests (uses DB)
    api: API endpoint tests
```

### Fixtures (create conftest.py with these)
```python
@pytest.fixture
def admin_user(db): ...
@pytest.fixture
def manager_user(db): ...
@pytest.fixture
def officer_user(db): ...
@pytest.fixture
def donor_user(db): ...
@pytest.fixture
def sample_ngo(db): ...
@pytest.fixture
def sample_project(db, sample_ngo, manager_user): ...
@pytest.fixture
def api_client(): ...
@pytest.fixture
def auth_client(api_client, manager_user): ...
```

---

## BUILD PHASES (Complete in order — confirm with user before advancing)

---

### PHASE 1: Backend Foundation
**Goal**: Working Django project with all models, migrations, and auth endpoints
**Completion criteria**: All migrations run cleanly; register/login/refresh/logout work; 
pytest passes for accounts app

**Steps**:
1. Create Django project with split settings (base/development/production)
2. Install and configure all requirements (base.txt, development.txt)
3. Create CustomUser model (email-based login, role field, ngo_id FK)
4. Create all 11 models across their respective apps
5. Run and verify migrations — confirm all tables and indexes created
6. Configure simplejwt with 15min/7day expiry and blacklisting
7. Configure BCryptSHA256PasswordHasher and password validators
8. Configure DRF throttling (20/min anon, 100/min user)
9. Create all 5 custom permission classes with full docstrings
10. Implement auth endpoints: register, login, refresh, logout, me
11. Implement password reset flow (token generation, email, confirm)
12. Configure drf-spectacular at /api/v1/docs/
13. Create core/ response wrapper and exception handler
14. Write tests for accounts app (models, permissions, all auth endpoints)
15. Update HANDOVER.md and PROGRESS.md

**Stop here and confirm before Phase 2.**

---

### PHASE 2: Core API
**Goal**: All CRUD endpoints working for every resource
**Completion criteria**: All endpoints return correct data; RBAC enforced; 
Swagger UI shows all endpoints; pytest coverage >80%

**Steps**:
1. NGO serializer, views, URLs (admin only)
2. Project serializer (with budget, dates validation), views, URLs
3. ProjectAssignment sub-resource with business logic
4. Beneficiary serializer (with computed age field), views, URLs
5. Indicator serializer (with computed progress_percentage), views, URLs
6. Milestone serializer (with auto-overdue logic), views, URLs
7. Report serializer with workflow validation, views, URLs
8. ReportImage upload endpoint with MIME + size validation
9. Notification views with mark-all-read endpoint
10. User management views (admin only)
11. Analytics/dashboard endpoint (role-filtered stats)
12. Multi-tenant filtering: ensure every queryset is filtered by ngo_id
13. Standard pagination configured globally
14. Write tests for all apps (models, serializers, views, permissions)
15. Run full test suite — fix any failures before advancing
16. Update HANDOVER.md and PROGRESS.md

**Stop here and confirm before Phase 3.**

---

### PHASE 3: Advanced Backend Features
**Goal**: PDF reports, notifications, signals, and export endpoints
**Completion criteria**: PDF generation works; Django signals fire correctly; 
notifications created on all trigger events; CSV export works

**Steps**:
1. Django signals in each relevant app (use apps.py ready() method)
2. Notification signals: project assignment, officer removal, report approval,
   milestone due in 3 days (management command for the 3-day check)
3. PDF report generation with ReportLab:
   - Project summary report (for management)
   - Donor impact report (filtered to approved data only)
4. Beneficiary CSV export endpoint
5. Milestone auto-overdue management command
6. Write tests for signals and PDF generation
7. Update HANDOVER.md and PROGRESS.md

**Stop here and confirm before Phase 4.**

---

### PHASE 4: Flutter App
**Goal**: Complete Flutter app matching all 17 screens in the design system
**Completion criteria**: App connects to backend API; all screens functional;
role-based navigation works; GPS and photo upload work

**Steps**:
1. Flutter project setup with feature-based folder structure
2. pubspec.yaml with all dependencies (Dio, flutter_secure_storage, 
   geolocator, image_picker, Provider/Riverpod, GoRouter, fl_chart, sqflite)
3. Design system constants (AppColors, AppTextStyles, AppDimensions)
4. Dio client with JWT interceptor (attach, refresh, redirect)
5. SecureStorage wrapper class
6. GoRouter setup with role-based route guards
7. Auth feature: login, register, forgot password screens
8. Dashboard feature (role-aware)
9. Projects feature (list, detail with 4 tabs, create/edit)
10. Reports feature (list, detail, submit with GPS + photos)
11. Beneficiaries feature (list, register)
12. Indicators and milestones (shown within project detail tabs)
13. Notifications feature (with unread badge)
14. Profile screen
15. Admin screens: User Management, NGO Management
16. Analytics Dashboard with fl_chart charts
17. Loading shimmers, empty states, error states on all screens
18. Write widget tests for forms and key screens
19. Update HANDOVER.md and PROGRESS.md

**Stop here and confirm before Phase 5.**

---

### PHASE 5: Quality Assurance and Polish
**Goal**: Production-ready code with full test coverage and documentation
**Completion criteria**: All tests pass; no lint warnings; README complete; 
code is demo-ready for supervisor

**Steps**:
1. Run full backend test suite — fix all failures
2. Run flutter analyze — fix all warnings and errors
3. Run flutter test — fix all failures
4. Manual security test:
   - Test role boundaries (can officer access manager endpoints? NO)
   - Test token expiry and auto-refresh
   - Test rate limiting on auth endpoints
   - Test oversized image upload rejection
   - Test password reset token reuse rejection
5. Performance check: add __str__ to all models, add select_related/prefetch_related
   to querysets that have N+1 problems
6. Write README.md with:
   - Project overview
   - Setup instructions (backend + Flutter)
   - Environment variables needed
   - How to run tests
   - API documentation link
7. Final HANDOVER.md and PROGRESS.md update
8. Code review pass: remove any debug print statements, commented-out code,
   or placeholder TODOs

---

## WHAT GOOD LOOKS LIKE — EXAMPLES

### Good Model (follow this pattern)
```python
class Project(models.Model):
    """
    Represents an NGO project with lifecycle management.
    
    A project must always belong to an NGO (ngo_id is NOT NULL).
    Status transitions: planning → active → on_hold ↔ active → completed/cancelled.
    """
    
    class Status(models.TextChoices):
        PLANNING   = 'planning',   'Planning'
        ACTIVE     = 'active',     'Active'
        ON_HOLD    = 'on_hold',    'On Hold'
        COMPLETED  = 'completed',  'Completed'
        CANCELLED  = 'cancelled',  'Cancelled'
    
    project_name = models.CharField(max_length=255)
    description  = models.TextField(blank=True, null=True)
    budget       = models.DecimalField(max_digits=15, decimal_places=2)
    start_date   = models.DateField()
    end_date     = models.DateField()
    status       = models.CharField(max_length=20, choices=Status.choices, 
                                    default=Status.PLANNING)
    ngo          = models.ForeignKey('ngos.NGO', on_delete=models.RESTRICT, 
                                     related_name='projects')
    created_at   = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'projects'
        indexes = [
            models.Index(fields=['ngo', 'status']),
        ]
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.project_name} ({self.ngo.name})"
    
    def clean(self):
        """Validate that end_date is after start_date."""
        if self.end_date and self.start_date:
            if self.end_date <= self.start_date:
                raise ValidationError("end_date must be after start_date.")
```

### Good ViewSet (follow this pattern)
```python
class ProjectViewSet(viewsets.ModelViewSet):
    """
    CRUD endpoints for NGO projects.
    
    List is filtered by the requesting user's NGO.
    Create/Update restricted to managers and admins.
    Delete restricted to admins only.
    """
    serializer_class = ProjectSerializer
    pagination_class = StandardPagination
    filterset_fields = ['status', 'ngo']
    search_fields = ['project_name', 'description']
    ordering_fields = ['created_at', 'start_date', 'budget']
    
    def get_queryset(self):
        """Return only projects belonging to the requesting user's NGO."""
        return Project.objects.filter(
            ngo=self.request.user.ngo
        ).select_related('ngo').prefetch_related('assignments')
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update']:
            return [IsManagerOrAdmin()]
        if self.action == 'destroy':
            return [IsNGOAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        """Automatically set ngo from the requesting user."""
        serializer.save(ngo=self.request.user.ngo)
```

### Good Test (follow this pattern)
```python
@pytest.mark.api
class TestProjectEndpoints:
    """Tests for /api/v1/projects/ endpoints."""
    
    def test_list_projects_returns_only_own_ngo_projects(
        self, auth_client, sample_project, other_ngo_project
    ):
        """Manager should only see projects from their own NGO."""
        response = auth_client.get('/api/v1/projects/')
        assert response.status_code == 200
        project_ids = [p['id'] for p in response.data['results']]
        assert sample_project.id in project_ids
        assert other_ngo_project.id not in project_ids  # Multi-tenant isolation
    
    def test_create_project_requires_manager_role(self, api_client, officer_user):
        """Officers cannot create projects."""
        api_client.force_authenticate(user=officer_user)
        response = api_client.post('/api/v1/projects/', {...})
        assert response.status_code == 403
        assert response.data['code'] == 'PERMISSION_DENIED'
    
    def test_create_project_validates_end_date_after_start_date(
        self, auth_client
    ):
        """end_date must be after start_date."""
        response = auth_client.post('/api/v1/projects/', {
            'project_name': 'Test',
            'start_date': '2026-12-01',
            'end_date': '2026-01-01',  # Before start — should fail
            ...
        })
        assert response.status_code == 400
        assert 'end_date' in response.data
```

---

## START INSTRUCTIONS

When you begin your first session with this prompt:

1. Read this entire file completely
2. Check if HANDOVER.md exists — if yes, read it and resume from where it says
3. If starting fresh: confirm the folder structure, then begin Phase 1 Step 1
4. After every step, briefly confirm what was done before moving to the next
5. When context is getting low (you can feel it): stop, write HANDOVER.md, 
   tell the user "Context running low — HANDOVER.md updated. Resume next session."
6. Never silently skip a step — if something is hard, explain the problem 
   and propose solutions

The goal is a system that a supervisor assesses and says:
"This was clearly built by someone who understands software engineering."

Every variable name, every comment, every test, every commit message
should reflect that standard.
