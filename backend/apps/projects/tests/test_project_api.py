"""Tests for project CRUD, NGO scoping, and role permissions."""
import pytest

from apps.projects.models import Project

PROJECTS = "/api/v1/projects/"

pytestmark = pytest.mark.django_db


def _payload(**over):
    data = {"project_name": "Clean Water", "status": "planning", "budget": "1000.00"}
    data.update(over)
    return data


class TestCreate:
    def test_manager_creates_in_own_ngo(self, auth_client, manager_user):
        resp = auth_client(manager_user).post(PROJECTS, _payload(), format="json")
        assert resp.status_code == 201
        # ngo is forced to the manager's NGO regardless of payload.
        assert resp.data["ngo"] == manager_user.ngo_id

    def test_manager_ngo_cannot_be_spoofed(self, auth_client, manager_user, other_ngo):
        resp = auth_client(manager_user).post(
            PROJECTS, _payload(ngo=other_ngo.id), format="json"
        )
        assert resp.status_code == 201
        assert resp.data["ngo"] == manager_user.ngo_id  # not other_ngo

    def test_admin_must_supply_ngo(self, auth_client, admin_user):
        resp = auth_client(admin_user).post(PROJECTS, _payload(), format="json")
        assert resp.status_code == 400

    def test_admin_creates_with_ngo(self, auth_client, admin_user, other_ngo):
        resp = auth_client(admin_user).post(
            PROJECTS, _payload(ngo=other_ngo.id), format="json"
        )
        assert resp.status_code == 201
        assert resp.data["ngo"] == other_ngo.id

    @pytest.mark.parametrize("fixture", ["officer_user", "donor_user"])
    def test_officer_and_donor_cannot_create(self, auth_client, request, fixture):
        user = request.getfixturevalue(fixture)
        resp = auth_client(user).post(PROJECTS, _payload(), format="json")
        assert resp.status_code == 403


class TestListScoping:
    def test_manager_sees_only_own_ngo(self, auth_client, manager_user, ngo, other_ngo):
        Project.objects.create(project_name="Mine", ngo=ngo)
        Project.objects.create(project_name="Theirs", ngo=other_ngo)
        resp = auth_client(manager_user).get(PROJECTS)
        assert resp.status_code == 200
        assert {p["project_name"] for p in resp.data["results"]} == {"Mine"}

    def test_admin_sees_all(self, auth_client, admin_user, ngo, other_ngo):
        Project.objects.create(project_name="Mine", ngo=ngo)
        Project.objects.create(project_name="Theirs", ngo=other_ngo)
        resp = auth_client(admin_user).get(PROJECTS)
        assert resp.data["count"] == 2

    def test_officer_sees_only_assigned(self, auth_client, officer_user, ngo):
        from apps.projects.models import ProjectAssignment

        assigned = Project.objects.create(project_name="Assigned", ngo=ngo)
        Project.objects.create(project_name="Unassigned", ngo=ngo)
        ProjectAssignment.objects.create(project=assigned, user=officer_user, role="officer")
        resp = auth_client(officer_user).get(PROJECTS)
        assert {p["project_name"] for p in resp.data["results"]} == {"Assigned"}

    def test_filter_by_status(self, auth_client, manager_user, ngo):
        Project.objects.create(project_name="A", ngo=ngo, status="active")
        Project.objects.create(project_name="P", ngo=ngo, status="planning")
        resp = auth_client(manager_user).get(PROJECTS, {"status": "active"})
        assert {p["project_name"] for p in resp.data["results"]} == {"A"}


class TestUpdateDelete:
    def test_manager_cannot_touch_other_ngo_project(self, auth_client, manager_user, other_ngo):
        foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        # Out of the manager's queryset -> 404.
        assert auth_client(manager_user).patch(
            f"{PROJECTS}{foreign.id}/", {"status": "active"}, format="json"
        ).status_code == 404

    def test_manager_updates_own_ngo_project(self, auth_client, manager_user, ngo):
        proj = Project.objects.create(project_name="Mine", ngo=ngo)
        resp = auth_client(manager_user).patch(
            f"{PROJECTS}{proj.id}/", {"status": "active"}, format="json"
        )
        assert resp.status_code == 200
        assert resp.data["status"] == "active"
