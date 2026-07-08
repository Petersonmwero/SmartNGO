"""Helpers for issuing and consuming one-time tokens (password reset + email verification).

The raw token is sent to the user and never stored. Only its SHA-256 hash is
persisted, so a database leak does not expose usable tokens.
"""
import hashlib
import secrets
from datetime import timedelta

from django.utils import timezone

from .models import EmailVerificationToken, PasswordResetToken

RESET_TOKEN_TTL = timedelta(hours=1)
VERIFY_TOKEN_TTL = timedelta(hours=24)


def hash_token(raw_token):
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def issue_reset_token(user):
    """Invalidate any outstanding tokens, then create and return a fresh raw token."""
    PasswordResetToken.objects.filter(user=user, used=False).update(used=True)
    raw_token = secrets.token_urlsafe(48)
    PasswordResetToken.objects.create(
        user=user,
        token=hash_token(raw_token),
        expires_at=timezone.now() + RESET_TOKEN_TTL,
    )
    return raw_token


def consume_reset_token(raw_token):
    """Return the matching unused, unexpired token row, or None.

    A matched-but-expired token is marked used so it cannot be retried.
    """
    try:
        record = PasswordResetToken.objects.select_related("user").get(
            token=hash_token(raw_token), used=False
        )
    except PasswordResetToken.DoesNotExist:
        return None

    if record.expires_at < timezone.now():
        record.used = True
        record.save(update_fields=["used"])
        return None
    return record


def issue_email_verification_token(user):
    """Invalidate any pending tokens for this user, then return a fresh raw token."""
    EmailVerificationToken.objects.filter(user=user, used=False).update(used=True)
    raw_token = secrets.token_urlsafe(32)
    EmailVerificationToken.objects.create(
        user=user,
        token=hash_token(raw_token),
        expires_at=timezone.now() + VERIFY_TOKEN_TTL,
    )
    return raw_token


def consume_email_verification_token(raw_token):
    """Return the matching unused, unexpired verification token row, or None.

    An expired token is marked used immediately so it cannot be retried.
    Caller is responsible for marking the returned token used after acting on it.
    """
    try:
        record = EmailVerificationToken.objects.select_related("user").get(
            token=hash_token(raw_token), used=False
        )
    except EmailVerificationToken.DoesNotExist:
        return None

    if record.expires_at < timezone.now():
        record.used = True
        record.save(update_fields=["used"])
        return None
    return record
