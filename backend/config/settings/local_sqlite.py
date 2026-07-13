"""
Local-run convenience settings: run the dev server on a file-based SQLite DB
when no MySQL server is available.

MySQL 8 remains the configured database for real dev/prod (see base.py); this
exists only so the app can be launched and clicked through locally without
standing up MySQL. The DB file (db.sqlite3) is gitignored.
"""
from .dev import *  # noqa: F401,F403

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
    }
}
