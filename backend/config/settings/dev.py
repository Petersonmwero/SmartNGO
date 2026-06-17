"""Local development settings."""
from .base import *  # noqa: F401,F403

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "0.0.0.0", "*"]

# Print emails (e.g. password-reset tokens) to the console during development.
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Allow any browser origin in development (Flutter web's dev-server port varies).
CORS_ALLOW_ALL_ORIGINS = True
