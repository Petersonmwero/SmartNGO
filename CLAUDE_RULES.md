# SMART NGO — OPERATING RULES
### Extracted from CLAUDE.md — these rules apply to every session

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
