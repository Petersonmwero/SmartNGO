"""Tests for beneficiary CRUD: age computation, soft-delete, officer access."""
from datetime import date, timedelta

import pytest
from django.utils import timezone

from apps.beneficiaries.models import Beneficiary
from apps.beneficiaries.serializers import BeneficiarySerializer
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
    # Fully populated so it satisfies both the minor rules (guardian present)
    # and the adult rules (national_id present); individual tests strip fields
    # to exercise the age-conditional validation.
    data = {
        "name": "Baby Doe",
        "gender": "female",
        "date_of_birth": "2020-06-17",
        "phone": "0712345678",
        "national_id": "12345678",
        "guardian_name": "Jane Doe",
        "guardian_phone": "0722000000",
        "consent_given": True,
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


# A DOB roughly 30 years ago (adult) and one roughly 10 years ago (minor),
# both derived from today so the tests never drift as the clock advances.
ADULT_DOB = (date.today() - timedelta(days=30 * 365)).isoformat()
MINOR_DOB = (date.today() - timedelta(days=10 * 365)).isoformat()


class TestAgeConditionalValidation:
    """Requirements are frozen at registration age (Part 2)."""

    def test_adult_without_national_id_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, date_of_birth=ADULT_DOB, national_id=""),
            format="json",
        )
        assert resp.status_code == 400
        assert "national_id" in resp.data["error"]

    def test_adult_without_guardian_allowed(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, date_of_birth=ADULT_DOB, guardian_name="", guardian_phone=""),
            format="json",
        )
        assert resp.status_code == 201

    def test_minor_without_national_id_allowed(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, date_of_birth=MINOR_DOB, national_id=""),
            format="json",
        )
        assert resp.status_code == 201

    def test_minor_without_guardian_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, date_of_birth=MINOR_DOB, guardian_name="", guardian_phone=""),
            format="json",
        )
        assert resp.status_code == 400
        assert "guardian_name" in resp.data["error"] or "guardian_phone" in resp.data["error"]

    def test_no_contact_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, date_of_birth=ADULT_DOB, phone="", guardian_phone=""),
            format="json",
        )
        assert resp.status_code == 400

    def test_guardian_phone_only_allowed(self, auth_client, manager_user, project):
        # Minor with no personal phone but a guardian phone is reachable.
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, date_of_birth=MINOR_DOB, phone=""),
            format="json",
        )
        assert resp.status_code == 201

    def test_no_consent_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, consent_given=False),
            format="json",
        )
        assert resp.status_code == 400
        assert "consent_given" in resp.data["error"]

    def test_invalid_kenyan_phone_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).post(
            BENEFICIARIES,
            _payload(project.id, phone="12345"),
            format="json",
        )
        assert resp.status_code == 400
        assert "phone" in resp.data["error"]

    def test_minor_stays_valid_after_turning_18(self, manager_user, project):
        """A beneficiary registered as a minor is not retroactively invalidated
        once they cross 18 — the rules are pinned to registration age."""
        # Registered 10 years ago at age 8 (guardian, no national_id); now ~18.
        b = Beneficiary.objects.create(
            name="Grown Up",
            gender="male",
            date_of_birth=date.today() - timedelta(days=18 * 365),
            guardian_name="Guardian",
            guardian_phone="0722000000",
            consent_given=True,
            project=project,
        )
        Beneficiary.objects.filter(pk=b.pk).update(
            created_at=timezone.now() - timedelta(days=10 * 365)
        )
        b.refresh_from_db()
        # Age today is ~18, but at registration they were ~8 (a minor).
        assert b.age_at_registration() < 18
        # A partial update (no national_id) must still validate.
        serializer = BeneficiarySerializer(instance=b, data={"name": "Grown Up"}, partial=True)
        assert serializer.is_valid(), serializer.errors
