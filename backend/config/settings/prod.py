"""Production settings — HTTPS hardening per security spec."""
from .base import *  # noqa: F401,F403

DEBUG = False

# Require explicit allowed hosts in production.
# ALLOWED_HOSTS is populated from DJANGO_ALLOWED_HOSTS in base.py.

# --- HTTPS / transport security ------------------------------------------
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# Real email backend should be configured here via environment variables.
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
