"""
CI settings: run the test suite against a real MySQL 8 service.

Inherits the MySQL database configuration from base (driven by DB_* env vars)
and keeps the in-memory email backend so the `mailoutbox` fixture works for
the password-reset tests. Media is written to a temp dir.
"""
import tempfile

from .dev import *  # noqa: F401,F403

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
MEDIA_ROOT = tempfile.mkdtemp(prefix="smartngo-ci-media-")
