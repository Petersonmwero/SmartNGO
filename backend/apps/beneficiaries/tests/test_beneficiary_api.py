"""Tests for beneficiary CRUD: age computation, soft-delete, officer access."""
import pytest

from apps.beneficiaries.models import Beneficiary
from apps.projects.models import Project, ProjectAssignment

BENEFICIARIES = "/api/v1/beneficiaries/"

pytestmark = pytest.mark.django_db


@pytest.fixture
def project(ngo):
    return Project.objects.create(project_name="Nutrition", ngo=ngo)


@pytest.fixture
def assigned_project(ngo, officer_user):
    project = Project.objects.create(project_name="Assigned", ngo=ngo)
    ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    return project


def _payload(project_id, **over):
    data = {
        "name": "Baby Doe",
        "gender": "female",
        "date_of_birth": "2020-06-17",
        "phone": "0700",
        "county": "Nandi",
        "constituency": "Chesumei",
        "ward": "Kaptel/Kamoiywo",
        "village": "Baraton",
        "project": project_id,
    }
    data.update(over)
    return data


class TestAge:
    def test_age_is_computed_not_stored(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES, _payload(project.id, date_of_birth="2000-06-17"), format="json"
        )
        assert resp.status_code == 201
        # 2000-06-17 -> 26 on 2026-06-17 (today per environment).
        assert resp.data["age"] == 26
        assert "age" not in [f.name for f in Beneficiary._meta.get_fields()]

    def test_future_dob_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES, _payload(project.id, date_of_birth="2999-01-01"), format="json"
        )
        assert resp.status_code == 400


class TestOfficerAccess:
    def test_officer_can_register_on_assigned_project(self, auth_client, officer_user, assigned_project):
        resp = auth_client(officer_user).post(
            BENEFICIARIES, _payload(assigned_project.id), format="json"
        )
        assert resp.status_code == 201

    def test_officer_cannot_register_on_unassigned_project(self, auth_client, officer_user, project):
        resp = auth_client(officer_user).post(
            BENEFICIARIES, _payload(project.id), format="json"
        )
        assert resp.status_code == 403

    def test_donor_cannot_create(self, auth_client, donor_user, project):
        resp = auth_client(donor_user).post(
            BENEFICIARIES, _payload(project.id), format="json"
        )
        assert resp.status_code == 403


class TestScopingAndSoftDelete:
    def test_manager_blocked_on_other_ngo_project(self, auth_client, manager_user, other_ngo):
        foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        resp = auth_client(manager_user).post(
            BENEFICIARIES, _payload(foreign.id), format="json"
        )
        assert resp.status_code == 403

    def test_destroy_soft_deletes(self, auth_client, manager_user, project):
        b = Beneficiary.objects.create(name="X", gender="male", project=project)
        resp = auth_client(manager_user).delete(f"{BENEFICIARIES}{b.id}/")
        assert resp.status_code == 204
        b.refresh_from_db()
        assert b.is_active is False  # row still exists
        # Soft-deleted rows are hidden from the list.
        listed = auth_client(manager_user).get(BENEFICIARIES)
        assert b.id not in [row["id"] for row in listed.data["results"]]

    def test_filter_by_project_id(self, auth_client, manager_user, ngo, project):
        other = Project.objects.create(project_name="Other", ngo=ngo)
        Beneficiary.objects.create(name="A", gender="male", project=project)
        Beneficiary.objects.create(name="B", gender="male", project=other)
        resp = auth_client(manager_user).get(BENEFICIARIES, {"project_id": project.id})
        assert {row["name"] for row in resp.data["results"]} == {"A"}
