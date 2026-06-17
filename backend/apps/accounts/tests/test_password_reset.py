"""Tests for the password-reset request/confirm flow."""
import re

import pytest

from apps.accounts.models import PasswordResetToken
from apps.accounts.tokens import issue_reset_token
from conftest import PASSWORD

REQUEST = "/api/v1/auth/password-reset/"
CONFIRM = "/api/v1/auth/password-reset/confirm/"
LOGIN = "/api/v1/auth/login/"
NEW_PASSWORD = "BrandNewPass1!"

pytestmark = pytest.mark.django_db


def _token_from_mail(mailoutbox):
    body = mailoutbox[-1].body
    match = re.search(r"Reset token:\s*(\S+)", body)
    return match.group(1) if match else None


class TestRequest:
    def test_request_sends_email_for_real_user(self, api_client, officer_user, mailoutbox):
        resp = api_client.post(REQUEST, {"email": officer_user.email}, format="json")
        assert resp.status_code == 200
        assert len(mailoutbox) == 1
        token = _token_from_mail(mailoutbox)
        assert token
        # Only the hash is stored, never the raw token.
        assert not PasswordResetToken.objects.filter(token=token).exists()

    def test_unknown_email_does_not_enumerate(self, api_client, mailoutbox):
        resp = api_client.post(REQUEST, {"email": "ghost@example.org"}, format="json")
        assert resp.status_code == 200
        assert len(mailoutbox) == 0

    def test_new_request_invalidates_previous_token(self, api_client, officer_user, mailoutbox):
        api_client.post(REQUEST, {"email": officer_user.email}, format="json")
        first = _token_from_mail(mailoutbox)
        api_client.post(REQUEST, {"email": officer_user.email}, format="json")

        # The first token must no longer work.
        resp = api_client.post(
            CONFIRM, {"token": first, "new_password": NEW_PASSWORD}, format="json"
        )
        assert resp.status_code == 400


class TestConfirm:
    def test_confirm_resets_password(self, api_client, officer_user, mailoutbox):
        api_client.post(REQUEST, {"email": officer_user.email}, format="json")
        token = _token_from_mail(mailoutbox)

        resp = api_client.post(
            CONFIRM, {"token": token, "new_password": NEW_PASSWORD}, format="json"
        )
        assert resp.status_code == 200

        assert api_client.post(
            LOGIN, {"email": officer_user.email, "password": NEW_PASSWORD}, format="json"
        ).status_code == 200
        assert api_client.post(
            LOGIN, {"email": officer_user.email, "password": PASSWORD}, format="json"
        ).status_code == 401

    def test_token_is_single_use(self, api_client, officer_user, mailoutbox):
        api_client.post(REQUEST, {"email": officer_user.email}, format="json")
        token = _token_from_mail(mailoutbox)
        api_client.post(CONFIRM, {"token": token, "new_password": NEW_PASSWORD}, format="json")

        resp = api_client.post(
            CONFIRM, {"token": token, "new_password": "AnotherPass1!"}, format="json"
        )
        assert resp.status_code == 400

    def test_bad_token_rejected(self, api_client):
        resp = api_client.post(
            CONFIRM, {"token": "not-real", "new_password": NEW_PASSWORD}, format="json"
        )
        assert resp.status_code == 400

    def test_weak_new_password_rejected(self, api_client, officer_user, mailoutbox):
        api_client.post(REQUEST, {"email": officer_user.email}, format="json")
        token = _token_from_mail(mailoutbox)
        resp = api_client.post(CONFIRM, {"token": token, "new_password": "weak"}, format="json")
        assert resp.status_code == 400

    def test_expired_token_rejected(self, api_client, officer_user):
        from datetime import timedelta

        from django.utils import timezone

        raw = issue_reset_token(officer_user)
        record = PasswordResetToken.objects.get(user=officer_user, used=False)
        record.expires_at = timezone.now() - timedelta(minutes=1)
        record.save(update_fields=["expires_at"])

        resp = api_client.post(
            CONFIRM, {"token": raw, "new_password": NEW_PASSWORD}, format="json"
        )
        assert resp.status_code == 400
