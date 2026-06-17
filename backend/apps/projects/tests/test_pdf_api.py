"""Tests for the PDF generation endpoints (donor summary, monthly report)."""
from datetime import datetime, timezone as dt_timezone

import pytest

from apps.indicators.models import Indicator
from apps.projects.models import Milestone, Project, ProjectAssignment
from apps.reports.models import Report

pytestmark = pytest.mark.django_db


@pytest.fixture
def project(ngo):
    p = Project.objects.create(project_name="WASH", ngo=ngo, budget="50000.00", status="active")
    Indicator.objects.create(project=p, indicator_name="Wells", target_value=50, current_value=20, unit="wells")
    Milestone.objects.create(project=p, title="Baseline", due_date="2026-09-01", status="pending")
    return p


def _is_pdf(response):
    return (
        response.status_code == 200
        and response["Content-Type"] == "application/pdf"
        and response.content[:4] == b"%PDF"
    )


class TestSummaryPdf:
    def test_manager_gets_summary_pdf(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).get(f"/api/v1/projects/{project.id}/summary-pdf/")
        assert _is_pdf(resp)
        assert "attachment" in resp["Content-Disposition"]

    def test_donor_gets_summary_for_own_ngo(self, auth_client, donor_user, project):
        resp = auth_client(donor_user).get(f"/api/v1/projects/{project.id}/summary-pdf/")
        assert _is_pdf(resp)

    def test_donor_blocked_on_other_ngo_project(self, auth_client, donor_user, other_ngo):
        foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        resp = auth_client(donor_user).get(f"/api/v1/projects/{foreign.id}/summary-pdf/")
        assert resp.status_code == 404

    def test_officer_needs_assignment(self, auth_client, officer_user, project):
        # Not assigned -> project not in queryset -> 404.
        assert auth_client(officer_user).get(
            f"/api/v1/projects/{project.id}/summary-pdf/"
        ).status_code == 404
        ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
        assert _is_pdf(auth_client(officer_user).get(f"/api/v1/projects/{project.id}/summary-pdf/"))


class TestMonthlyReportPdf:
    def test_monthly_report_pdf(self, auth_client, manager_user, officer_user, project):
        Report.objects.create(
            project=project, officer=officer_user, title="Approved one",
            report_type="monthly", status=Report.Status.APPROVED,
            date_submitted=datetime(2026, 5, 15, tzinfo=dt_timezone.utc),
        )
        resp = auth_client(manager_user).get(
            f"/api/v1/projects/{project.id}/monthly-report/", {"year": 2026, "month": 5}
        )
        assert _is_pdf(resp)

    def test_invalid_month_rejected(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).get(
            f"/api/v1/projects/{project.id}/monthly-report/", {"year": 2026, "month": 13}
        )
        assert resp.status_code == 400

    def test_defaults_to_current_month(self, auth_client, manager_user, project):
        resp = auth_client(manager_user).get(f"/api/v1/projects/{project.id}/monthly-report/")
        assert _is_pdf(resp)
