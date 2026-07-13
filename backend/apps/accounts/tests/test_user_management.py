"""Tests for /api/v1/users/ — admin user management."""
import pytest

from apps.accounts.models import Role

USERS = "/api/v1/users/"

pytestmark = pytest.mark.django_db


class TestUserManagementList:
    def test_admin_can_list_users_in_own_ngo(self, auth_client, admin_user, officer_user):
        resp = auth_client(admin_user).get(USERS)
        assert resp.status_code == 200
        emails = {u["email"] for u in resp.data["results"]}
        assert admin_user.email in emails
        assert officer_user.email in emails

    def test_admin_cannot_see_other_ngo_users(self, auth_client, admin_user, other_ngo, ngo):
        from apps.accounts.models import User
        other = User.objects.create_user(
            email="other@elsewhere.org", password="Pw!12345",
            first_name="Other", last_name="", role=Role.OFFICER, ngo=other_ngo,
        )
        resp = auth_client(admin_user).get(USERS)
        emails = {u["email"] for u in resp.data["results"]}
        assert other.email not in emails

    def test_manager_can_list_users_in_own_ngo(
        self, auth_client, manager_user, officer_user
    ):
        """Managers need the officer roster to assign project teams."""
        resp = auth_client(manager_user).get(USERS)
        assert resp.status_code == 200
        emails = {u["email"] for u in resp.data["results"]}
        assert officer_user.email in emails

    def test_manager_cannot_see_other_ngo_users(
        self, auth_client, manager_user, other_ngo
    ):
        from apps.accounts.models import User
        other = User.objects.create_user(
            email="hidden@elsewhere.org", password="Pw!12345",
            first_name="Hidden", last_name="", role=Role.OFFICER, ngo=other_ngo,
        )
        resp = auth_client(manager_user).get(USERS)
        emails = {u["email"] for u in resp.data["results"]}
        assert other.email not in emails

    def test_officer_is_denied(self, auth_client, officer_user):
        resp = auth_client(officer_user).get(USERS)
        assert resp.status_code == 403

    def test_donor_is_denied(self, auth_client, donor_user):
        resp = auth_client(donor_user).get(USERS)
        assert resp.status_code == 403

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(USERS)
        assert resp.status_code == 401


class TestUserManagementCreate:
    def test_admin_can_create_manager(self, auth_client, admin_user, ngo):
        payload = {
            "first_name": "New",
            "last_name": "Manager",
            "email": "newmgr@test.org",
            "password": "Secure!99",
            "role": "manager",
            "ngo": ngo.id,
        }
        resp = auth_client(admin_user).post(USERS, payload, format="json")
        assert resp.status_code == 201
        assert resp.data["role"] == "manager"

    def test_admin_can_create_admin(self, auth_client, admin_user, ngo):
        payload = {
            "first_name": "New",
            "last_name": "Admin",
            "email": "newadmin@test.org",
            "password": "Secure!99",
            "role": "admin",
            "ngo": ngo.id,
        }
        resp = auth_client(admin_user).post(USERS, payload, format="json")
        assert resp.status_code == 201

    def test_manager_cannot_create_user(self, auth_client, manager_user, ngo):
        """Manager read access must not extend to write actions."""
        payload = {
            "first_name": "Sneaky",
            "last_name": "Manager",
            "email": "sneaky@test.org",
            "password": "Secure!99",
            "role": "officer",
            "ngo": ngo.id,
        }
        resp = auth_client(manager_user).post(USERS, payload, format="json")
        assert resp.status_code == 403


class TestUserManagementToggleActive:
    def test_admin_can_deactivate_user(self, auth_client, admin_user, officer_user):
        assert officer_user.is_active is True
        resp = auth_client(admin_user).patch(f"{USERS}{officer_user.id}/toggle-active/")
        assert resp.status_code == 200
        assert resp.data["data"]["is_active"] is False
        officer_user.refresh_from_db()
        assert officer_user.is_active is False

    def test_toggle_twice_reactivates(self, auth_client, admin_user, officer_user):
        auth_client(admin_user).patch(f"{USERS}{officer_user.id}/toggle-active/")
        resp = auth_client(admin_user).patch(f"{USERS}{officer_user.id}/toggle-active/")
        assert resp.data["data"]["is_active"] is True

    def test_non_admin_cannot_toggle(self, auth_client, manager_user, officer_user):
        resp = auth_client(manager_user).patch(f"{USERS}{officer_user.id}/toggle-active/")
        assert resp.status_code == 403
