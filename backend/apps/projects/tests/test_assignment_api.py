"""Tests for the nested project-assignments sub-resource."""
import pytest

from apps.accounts.models import Role, User
from apps.projects.models import Project, ProjectAssignment

pytestmark = pytest.mark.django_db


def _assignments_url(project_id):
    return f"/api/v1/projects/{project_id}/assignments/"


@pytest.fixture
def project(ngo):
    return Project.objects.create(project_name="Field Work", ngo=ngo)


class TestCreateAssignment:
    def test_manager_assigns_officer(self, auth_client, manager_user, project, officer_user):
        resp = auth_client(manager_user).post(
            _assignments_url(project.id),
            {"user": officer_user.id, "role": "officer"},
            format="json",
        )
        assert resp.status_code == 201
        assert resp.data["user_name"] == officer_user.full_name

    def test_cannot_assign_user_from_other_ngo(self, auth_client, manager_user, project, other_ngo):
        outsider = User.objects.create_user(
            "outsider@x.org", "Pw!12345", full_name="Out", role=Role.OFFICER, ngo=other_ngo
        )
        resp = auth_client(manager_user).post(
            _assignments_url(project.id),
            {"user": outsider.id, "role": "officer"},
            format="json",
        )
        assert resp.status_code == 400

    def test_duplicate_assignment_rejected(self, auth_client, manager_user, project, officer_user):
        ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
        resp = auth_client(manager_user).post(
            _assignments_url(project.id),
            {"user": officer_user.id, "role": "officer"},
            format="json",
        )
        assert resp.status_code == 400

    def test_officer_cannot_assign(self, auth_client, officer_user, project):
        resp = auth_client(officer_user).post(
            _assignments_url(project.id),
            {"user": officer_user.id, "role": "officer"},
            format="json",
        )
        assert resp.status_code == 403

    def test_manager_cannot_assign_on_other_ngo_project(self, auth_client, manager_user, other_ngo, officer_user):
        foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        resp = auth_client(manager_user).post(
            _assignments_url(foreign.id),
            {"user": officer_user.id, "role": "officer"},
            format="json",
        )
        assert resp.status_code == 403


class TestListDeleteAssignment:
    def test_list_assignments(self, auth_client, manager_user, project, officer_user):
        ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
        resp = auth_client(manager_user).get(_assignments_url(project.id))
        assert resp.status_code == 200
        assert resp.data["count"] == 1

    def test_delete_assignment(self, auth_client, manager_user, project, officer_user):
        a = ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
        resp = auth_client(manager_user).delete(f"{_assignments_url(project.id)}{a.id}/")
        assert resp.status_code == 204
        assert not ProjectAssignment.objects.filter(id=a.id).exists()
