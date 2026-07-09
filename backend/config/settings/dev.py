"""Local development settings."""
from .base import *  # noqa: F401,F403

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "0.0.0.0", "*"]

# Email uses Gmail SMTP (configured in base.py). Set EMAIL_HOST_USER and
# EMAIL_HOST_PASSWORD in backend/.env. Emails fail silently if not configured.

# Allow any browser origin in development (Flutter web's dev-server port varies).
CORS_ALLOW_ALL_ORIGINS = True
