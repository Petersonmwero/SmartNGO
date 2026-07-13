"""Tests for the email verification flow added to registration and login."""
import pytest
from django.core import mail

from apps.accounts.models import EmailVerificationToken, User
from apps.accounts.tokens import (
    consume_email_verification_token,
    hash_token,
    issue_email_verification_token,
)
from conftest import PASSWORD

REGISTER = "/api/v1/auth/register/"
LOGIN = "/api/v1/auth/login/"
VERIFY = "/api/v1/auth/verify-email/"
RESEND = "/api/v1/auth/resend-verification/"

pytestmark = pytest.mark.django_db


# ---------------------------------------------------------------------------
# Registration flow
# ---------------------------------------------------------------------------

class TestRegistrationEmailVerification:
    def test_register_creates_inactive_user(self, api_client, ngo):
        """Newly registered user must be inactive until email is verified."""
        resp = api_client.post(
            REGISTER,
            {
                "first_name": "New", "last_name": "User",
                "email": "new@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert resp.status_code == 201
        user = User.objects.get(email="new@example.org")
        assert user.is_active is False

    def test_register_creates_verification_token(self, api_client, ngo):
        """A verification token must be created for the new user."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Token", "last_name": "User",
                "email": "token@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        user = User.objects.get(email="token@example.org")
        assert EmailVerificationToken.objects.filter(user=user, used=False).exists()

    def test_register_sends_verification_email(self, api_client, ngo):
        """Registration must trigger an outgoing verification email."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Email", "last_name": "User",
                "email": "email@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert len(mail.outbox) == 1
        sent = mail.outbox[0]
        assert "email@example.org" in sent.to
        assert "verify" in sent.subject.lower()
        assert "verify-email" in sent.body

    def test_register_response_contains_success_message(self, api_client, ngo):
        """Registration response must indicate that a verification email was sent."""
        resp = api_client.post(
            REGISTER,
            {
                "first_name": "Msg", "last_name": "User",
                "email": "msg@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert resp.status_code == 201
        assert resp.data["status"] == "success"
        assert "verification" in resp.data["message"].lower()

    def test_manager_can_self_register(self, api_client, ngo):
        """Project Managers are allowed to self-register (admin is the only blocked role)."""
        resp = api_client.post(
            REGISTER,
            {
                "first_name": "New", "last_name": "Manager",
                "email": "mgr@example.org",
                "password": PASSWORD,
                "role": "manager",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert resp.status_code == 201

    def test_admin_role_blocked_on_public_register(self, api_client, ngo):
        """Admin accounts must be rejected on the public register endpoint."""
        resp = api_client.post(
            REGISTER,
            {
                "first_name": "Bad", "last_name": "Actor",
                "email": "evil@example.org",
                "password": PASSWORD,
                "role": "admin",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert resp.status_code == 400
        assert resp.data["code"] == "invalid"


# ---------------------------------------------------------------------------
# Verify-email endpoint
# ---------------------------------------------------------------------------

class TestVerifyEmailEndpoint:
    def _register_and_get_token(self, api_client, ngo, email="verify@example.org"):
        """Helper: register a user and return the raw verification token."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Verify", "last_name": "Me",
                "email": email,
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        user = User.objects.get(email=email)
        # Re-issue so we can get the raw token (the view hashes it before storing).
        raw = issue_email_verification_token(user)
        return user, raw

    def test_valid_token_activates_user(self, api_client, ngo):
        """A valid token must flip is_active to True and serve the branded success page."""
        user, raw = self._register_and_get_token(api_client, ngo, "valid@example.org")
        resp = api_client.get(VERIFY, {"token": raw})
        assert resp.status_code == 200
        assert resp["Content-Type"].startswith("text/html")
        page = resp.content.decode()
        assert "Email Verified Successfully!" in page
        assert user.first_name in page  # personalised greeting
        user.refresh_from_db()
        assert user.is_active is True

    def test_valid_token_marked_used(self, api_client, ngo):
        """The token must be marked used after successful verification."""
        user, raw = self._register_and_get_token(api_client, ngo, "used@example.org")
        api_client.get(VERIFY, {"token": raw})
        token_hash = hash_token(raw)
        record = EmailVerificationToken.objects.get(token=token_hash)
        assert record.used is True

    def test_token_reuse_rejected(self, api_client, ngo):
        """Attempting to use the same token twice must return 400."""
        user, raw = self._register_and_get_token(api_client, ngo, "reuse@example.org")
        api_client.get(VERIFY, {"token": raw})
        resp = api_client.get(VERIFY, {"token": raw})
        assert resp.status_code == 400
        assert resp.data["code"] == "token_invalid"

    def test_invalid_token_rejected(self, api_client):
        """A made-up token must return 400."""
        resp = api_client.get(VERIFY, {"token": "notarealtoken"})
        assert resp.status_code == 400
        assert resp.data["code"] == "token_invalid"

    def test_missing_token_returns_400(self, api_client):
        """Calling the endpoint without a token must return 400."""
        resp = api_client.get(VERIFY)
        assert resp.status_code == 400
        assert resp.data["code"] == "token_required"


# ---------------------------------------------------------------------------
# Login blocked for unverified users
# ---------------------------------------------------------------------------

class TestLoginBlockedForUnverified:
    def test_unverified_user_cannot_login(self, api_client, ngo):
        """Login must be blocked when the user has not verified their email."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Unverified", "last_name": "",
                "email": "unverified@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        resp = api_client.post(
            LOGIN,
            {"email": "unverified@example.org", "password": PASSWORD},
            format="json",
        )
        assert resp.status_code == 401
        assert resp.data["code"] == "EMAIL_NOT_VERIFIED"

    def test_verified_user_can_login(self, api_client, ngo):
        """Login must succeed after email verification."""
        email = "verified@example.org"
        api_client.post(
            REGISTER,
            {
                "first_name": "Verified", "last_name": "",
                "email": email,
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        user = User.objects.get(email=email)
        raw = issue_email_verification_token(user)
        api_client.get(VERIFY, {"token": raw})  # verify

        resp = api_client.post(LOGIN, {"email": email, "password": PASSWORD}, format="json")
        assert resp.status_code == 200
        assert "access" in resp.data

    def test_login_error_has_correct_code(self, api_client, ngo):
        """The 401 response must use code EMAIL_NOT_VERIFIED."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Code", "last_name": "Check",
                "email": "code@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        resp = api_client.post(
            LOGIN,
            {"email": "code@example.org", "password": PASSWORD},
            format="json",
        )
        assert resp.data["code"] == "EMAIL_NOT_VERIFIED"
        assert "verify" in resp.data["error"].lower()


# ---------------------------------------------------------------------------
# Resend verification
# ---------------------------------------------------------------------------

class TestResendVerification:
    def test_resend_sends_email(self, api_client, ngo):
        """Resend must send a new verification email."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Resend", "last_name": "User",
                "email": "resend@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        mail.outbox.clear()
        resp = api_client.post(RESEND, {"email": "resend@example.org"}, format="json")
        assert resp.status_code == 200
        assert len(mail.outbox) == 1

    def test_resend_issues_new_token(self, api_client, ngo):
        """Resend must invalidate the old token and create a fresh one."""
        api_client.post(
            REGISTER,
            {
                "first_name": "Token", "last_name": "Rotate",
                "email": "rotate@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        user = User.objects.get(email="rotate@example.org")
        old_token = EmailVerificationToken.objects.get(user=user, used=False)

        api_client.post(RESEND, {"email": "rotate@example.org"}, format="json")

        old_token.refresh_from_db()
        assert old_token.used is True
        assert EmailVerificationToken.objects.filter(user=user, used=False).count() == 1

    def test_resend_unknown_email_still_returns_200(self, api_client):
        """Resend must always return 200 to prevent user enumeration."""
        resp = api_client.post(RESEND, {"email": "ghost@example.org"}, format="json")
        assert resp.status_code == 200
