"""
Test settings: run the suite against an in-memory SQLite database.

MySQL 8 remains the configured database for dev and prod (see base.py). This
override exists only so tests can run without a live MySQL server, which is the
standard approach for fast, isolated unit tests.
"""
import tempfile

from .dev import *  # noqa: F401,F403

# Keep uploaded test files out of the repo's media/ directory.
MEDIA_ROOT = tempfile.mkdtemp(prefix="smartngo-test-media-")

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": ":memory:",
    }
}

# In-memory email so tests can inspect sent messages via the `mailoutbox` fixture.
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
