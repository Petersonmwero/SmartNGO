"""Tests for GET /api/v1/auth/me/ — current user profile endpoint."""
import pytest

ME = "/api/v1/auth/me/"

pytestmark = pytest.mark.django_db


class TestMeEndpoint:
    def test_returns_own_profile(self, auth_client, officer_user):
        resp = auth_client(officer_user).get(ME)
        assert resp.status_code == 200
        assert resp.data["email"] == officer_user.email
        assert resp.data["role"] == officer_user.role
        assert resp.data["id"] == officer_user.id

    def test_includes_expected_fields(self, auth_client, admin_user):
        resp = auth_client(admin_user).get(ME)
        assert resp.status_code == 200
        for field in ["id", "first_name", "last_name", "email", "role", "phone", "ngo", "is_active", "created_at"]:
            assert field in resp.data

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(ME)
        assert resp.status_code == 401

    def test_does_not_return_another_users_profile(self, auth_client, officer_user, manager_user):
        resp = auth_client(officer_user).get(ME)
        assert resp.data["email"] == officer_user.email
        assert resp.data["email"] != manager_user.email
