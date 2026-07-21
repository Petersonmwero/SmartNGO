"""Tests for GET /api/v1/analytics/dashboard/ — role-filtered stats."""
import pytest

from apps.beneficiaries.models import Beneficiary
from apps.notifications.models import Notification
from apps.projects.models import Project, ProjectAssignment
from apps.reports.models import Report

DASHBOARD = "/api/v1/analytics/dashboard/"

pytestmark = pytest.mark.django_db


@pytest.fixture
def project(ngo):
    return Project.objects.create(project_name="Nutrition", ngo=ngo, status="active")


@pytest.fixture
def other_project(other_ngo):
    return Project.objects.create(project_name="External", ngo=other_ngo, status="active")


class TestDashboardResponseShape:
    def test_returns_expected_keys(self, auth_client, admin_user, project):
        resp = auth_client(admin_user).get(DASHBOARD)
        assert resp.status_code == 200
        assert resp.data["status"] == "success"
        data = resp.data["data"]
        assert "projects" in data
        assert "beneficiaries" in data
        assert "reports" in data
        assert "notifications" in data

    def test_projects_block_has_by_status(self, auth_client, admin_user, project):
        resp = auth_client(admin_user).get(DASHBOARD)
        proj = resp.data["data"]["projects"]
        assert "total" in proj
        assert "by_status" in proj
        for key in ("planning", "active", "on_hold", "completed", "cancelled"):
            assert key in proj["by_status"]

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(DASHBOARD)
        assert resp.status_code == 401


class TestDashboardNGOScoping:
    def test_admin_sees_projects_across_every_ngo(
        self, auth_client, admin_user, project, other_project
    ):
        """A system-wide admin counts other NGOs' projects too.

        The dashboard must agree with GET /projects/, which already returns
        every NGO's projects to an admin — a narrower count here rendered a
        stats card that contradicted the project list drawn beneath it.
        """
        resp = auth_client(admin_user).get(DASHBOARD)
        assert resp.data["data"]["projects"]["total"] == 2

    def test_admin_counts_derived_from_projects_span_ngos(
        self, auth_client, admin_user, officer_user, project, other_project
    ):
        """Beneficiary/report totals follow the widened admin project scope."""
        Beneficiary.objects.create(name="Ours", gender="female", project=project)
        Beneficiary.objects.create(
            name="Theirs", gender="male", project=other_project
        )
        Report.objects.create(
            title="Theirs", report_type="visit", project=other_project,
            officer=officer_user, status="submitted",
        )
        resp = auth_client(admin_user).get(DASHBOARD)
        assert resp.data["data"]["beneficiaries"]["total"] == 2
        assert resp.data["data"]["reports"]["submitted"] == 1

    def test_manager_sees_own_ngo_projects(
        self, auth_client, manager_user, project, other_project
    ):
        resp = auth_client(manager_user).get(DASHBOARD)
        assert resp.data["data"]["projects"]["total"] == 1

    def test_donor_sees_own_ngo_projects(
        self, auth_client, donor_user, project, other_project
    ):
        resp = auth_client(donor_user).get(DASHBOARD)
        assert resp.data["data"]["projects"]["total"] == 1


class TestDashboardOfficerScoping:
    def test_officer_with_no_assignments_sees_zero_projects(
        self, auth_client, officer_user
    ):
        resp = auth_client(officer_user).get(DASHBOARD)
        assert resp.data["data"]["projects"]["total"] == 0

    def test_officer_sees_only_assigned_projects(
        self, auth_client, officer_user, project, ngo
    ):
        unassigned = Project.objects.create(project_name="Unassigned", ngo=ngo)
        ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")

        resp = auth_client(officer_user).get(DASHBOARD)
        assert resp.data["data"]["projects"]["total"] == 1


class TestDashboardCounts:
    def test_beneficiary_count(self, auth_client, admin_user, project):
        Beneficiary.objects.create(
            name="Test Person", gender="female", project=project
        )
        resp = auth_client(admin_user).get(DASHBOARD)
        assert resp.data["data"]["beneficiaries"]["total"] == 1

    def test_report_status_counts(self, auth_client, admin_user, officer_user, project):
        Report.objects.create(
            title="Draft", report_type="visit", project=project, officer=officer_user,
            status="draft",
        )
        Report.objects.create(
            title="Submitted", report_type="visit", project=project, officer=officer_user,
            status="submitted",
        )
        resp = auth_client(admin_user).get(DASHBOARD)
        reports = resp.data["data"]["reports"]
        assert reports["draft"] == 1
        assert reports["submitted"] == 1
        assert reports["approved"] == 0

    def test_unread_notifications_count(self, auth_client, officer_user):
        Notification.objects.create(user=officer_user, title="a", status="unread")
        Notification.objects.create(user=officer_user, title="b", status="unread")
        Notification.objects.create(user=officer_user, title="c", status="read")
        resp = auth_client(officer_user).get(DASHBOARD)
        assert resp.data["data"]["notifications"]["unread"] == 2
