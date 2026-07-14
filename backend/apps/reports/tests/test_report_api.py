"""Tests for report CRUD and the draft -> submitted -> approved workflow."""
import pytest

from apps.reports.models import Report

REPORTS = "/api/v1/reports/"

pytestmark = pytest.mark.django_db


def _payload(project_id, **over):
    data = {
        "project": project_id,
        "title": "Daily update",
        "description": "All good",
        "report_type": "daily",
        "gps_latitude": "0.2827670",
        "gps_longitude": "35.1148460",
    }
    data.update(over)
    return data


class TestCreate:
    def test_officer_creates_draft_on_assigned_project(self, auth_client, officer_user, assigned_project):
        resp = auth_client(officer_user).post(
            REPORTS, _payload(assigned_project.id), format="json"
        )
        assert resp.status_code == 201
        assert resp.data["status"] == "draft"
        # officer (author) is set server-side, ignoring any client value.
        assert resp.data["officer"] == officer_user.id
        assert resp.data["date_submitted"] is None

    def test_officer_cannot_create_on_unassigned_project(self, auth_client, officer_user, ngo):
        from apps.projects.models import Project

        other = Project.objects.create(project_name="Other", ngo=ngo)
        resp = auth_client(officer_user).post(REPORTS, _payload(other.id), format="json")
        assert resp.status_code == 403

    def test_donor_cannot_create(self, auth_client, donor_user, assigned_project):
        resp = auth_client(donor_user).post(
            REPORTS, _payload(assigned_project.id), format="json"
        )
        assert resp.status_code == 403


class TestGpsPrecision:
    """Raw device coordinates exceed DECIMAL(10,7); the serializer must
    round to 7 decimal places instead of rejecting them."""

    def test_high_precision_coordinates_are_rounded_and_accepted(
        self, auth_client, officer_user, assigned_project
    ):
        resp = auth_client(officer_user).post(
            REPORTS,
            _payload(
                assigned_project.id,
                gps_latitude="-1.218110000000001",
                gps_longitude="36.887390000000004",
            ),
            format="json",
        )
        assert resp.status_code == 201
        assert float(resp.data["gps_latitude"]) == pytest.approx(-1.2181100)
        assert float(resp.data["gps_longitude"]) == pytest.approx(36.8873900)

    def test_out_of_range_latitude_rejected(
        self, auth_client, officer_user, assigned_project
    ):
        resp = auth_client(officer_user).post(
            REPORTS,
            _payload(assigned_project.id, gps_latitude="91.0"),
            format="json",
        )
        assert resp.status_code == 400

    def test_out_of_range_longitude_rejected(
        self, auth_client, officer_user, assigned_project
    ):
        resp = auth_client(officer_user).post(
            REPORTS,
            _payload(assigned_project.id, gps_longitude="-180.5"),
            format="json",
        )
        assert resp.status_code == 400

    def test_null_coordinates_still_allowed(
        self, auth_client, officer_user, assigned_project
    ):
        resp = auth_client(officer_user).post(
            REPORTS,
            _payload(assigned_project.id, gps_latitude=None, gps_longitude=None),
            format="json",
        )
        assert resp.status_code == 201
        assert resp.data["gps_latitude"] is None


class TestWorkflow:
    def test_author_submits_draft(self, auth_client, officer_user, draft_report):
        resp = auth_client(officer_user).post(f"{REPORTS}{draft_report.id}/submit/")
        assert resp.status_code == 200
        assert resp.data["status"] == "submitted"
        assert resp.data["date_submitted"] is not None

    def test_non_author_cannot_submit(self, auth_client, manager_user, draft_report):
        # manager is same NGO (can see it) but is not the author.
        resp = auth_client(manager_user).post(f"{REPORTS}{draft_report.id}/submit/")
        assert resp.status_code == 403

    def test_manager_approves_submitted(self, auth_client, manager_user, officer_user, draft_report):
        auth_client(officer_user).post(f"{REPORTS}{draft_report.id}/submit/")
        resp = auth_client(manager_user).post(f"{REPORTS}{draft_report.id}/approve/")
        assert resp.status_code == 200
        assert resp.data["status"] == "approved"

    def test_cannot_approve_draft(self, auth_client, manager_user, draft_report):
        resp = auth_client(manager_user).post(f"{REPORTS}{draft_report.id}/approve/")
        assert resp.status_code == 400

    def test_officer_cannot_approve(self, auth_client, officer_user, draft_report):
        auth_client(officer_user).post(f"{REPORTS}{draft_report.id}/submit/")
        resp = auth_client(officer_user).post(f"{REPORTS}{draft_report.id}/approve/")
        assert resp.status_code == 403


class TestEditLocking:
    def test_cannot_edit_submitted_report(self, auth_client, officer_user, draft_report):
        auth_client(officer_user).post(f"{REPORTS}{draft_report.id}/submit/")
        resp = auth_client(officer_user).patch(
            f"{REPORTS}{draft_report.id}/", {"title": "changed"}, format="json"
        )
        assert resp.status_code == 400

    def test_can_edit_draft(self, auth_client, officer_user, draft_report):
        resp = auth_client(officer_user).patch(
            f"{REPORTS}{draft_report.id}/", {"title": "changed"}, format="json"
        )
        assert resp.status_code == 200
        assert resp.data["title"] == "changed"


class TestScoping:
    def test_manager_sees_only_own_ngo_reports(self, auth_client, manager_user, other_ngo, draft_report):
        from apps.accounts.models import Role, User
        from apps.projects.models import Project

        foreign_officer = User.objects.create_user(
            "fo@x.org", "Pw!12345", first_name="FO", last_name="", role=Role.OFFICER, ngo=other_ngo
        )
        foreign_project = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        Report.objects.create(
            project=foreign_project, officer=foreign_officer, title="x", report_type="daily"
        )
        resp = auth_client(manager_user).get(REPORTS)
        assert resp.data["count"] == 1  # only the own-NGO draft_report
