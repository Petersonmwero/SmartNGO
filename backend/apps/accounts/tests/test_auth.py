"""Tests for registration, login, logout, and token refresh."""
import pytest

from conftest import PASSWORD

REGISTER = "/api/v1/auth/register/"
LOGIN = "/api/v1/auth/login/"
LOGOUT = "/api/v1/auth/logout/"
REFRESH = "/api/v1/auth/token/refresh/"

pytestmark = pytest.mark.django_db


class TestRegister:
    def test_register_officer_succeeds(self, api_client, ngo):
        """Registration returns 201 with a success envelope; user is inactive pending verification."""
        from apps.accounts.models import User

        resp = api_client.post(
            REGISTER,
            {
                "first_name": "Jane",
                "last_name": "Officer",
                "email": "jane@example.org",
                "password": PASSWORD,
                "role": "officer",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert resp.status_code == 201
        assert resp.data["status"] == "success"
        assert "verification" in resp.data["message"].lower()
        # Password must never appear in the response.
        assert "password" not in resp.data
        # Account is inactive until email is verified.
        user = User.objects.get(email="jane@example.org")
        assert user.is_active is False

    def test_cannot_self_register_as_admin(self, api_client, ngo):
        resp = api_client.post(
            REGISTER,
            {
                "first_name": "Sneaky",
                "last_name": "",
                "email": "evil@example.org",
                "password": PASSWORD,
                "role": "admin",
                "ngo": ngo.id,
            },
            format="json",
        )
        assert resp.status_code == 400
        assert set(resp.data) == {"error", "code"}

    def test_weak_password_rejected(self, api_client, ngo):
        resp = api_client.post(
            REGISTER,
            {"first_name": "Weak", "last_name": "", "email": "weak@example.org", "password": "short", "ngo": ngo.id},
            format="json",
        )
        assert resp.status_code == 400


class TestLoginLogout:
    def test_login_returns_tokens_and_user(self, api_client, officer_user):
        resp = api_client.post(
            LOGIN, {"email": officer_user.email, "password": PASSWORD}, format="json"
        )
        assert resp.status_code == 200
        assert "access" in resp.data and "refresh" in resp.data
        assert resp.data["user"]["role"] == "officer"

    def test_login_wrong_password(self, api_client, officer_user):
        resp = api_client.post(
            LOGIN, {"email": officer_user.email, "password": "nope"}, format="json"
        )
        assert resp.status_code == 401

    def test_logout_blacklists_refresh(self, api_client, auth_client, officer_user):
        login = api_client.post(
            LOGIN, {"email": officer_user.email, "password": PASSWORD}, format="json"
        )
        refresh = login.data["refresh"]
        client = auth_client(officer_user)

        out = client.post(LOGOUT, {"refresh": refresh}, format="json")
        assert out.status_code == 204

        # Blacklisted refresh can no longer be exchanged.
        again = api_client.post(REFRESH, {"refresh": refresh}, format="json")
        assert again.status_code == 401

    def test_logout_requires_authentication(self, api_client, officer_user):
        login = api_client.post(
            LOGIN, {"email": officer_user.email, "password": PASSWORD}, format="json"
        )
        resp = api_client.post(LOGOUT, {"refresh": login.data["refresh"]}, format="json")
        assert resp.status_code == 401


class TestRefresh:
    def test_refresh_returns_new_access(self, api_client, officer_user):
        login = api_client.post(
            LOGIN, {"email": officer_user.email, "password": PASSWORD}, format="json"
        )
        resp = api_client.post(REFRESH, {"refresh": login.data["refresh"]}, format="json")
        assert resp.status_code == 200
        assert "access" in resp.data
