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


class TestImpactPdf:
    """The donor impact PDF is downloadable by all four roles, NGO-scoped."""

    def _url(self, project):
        return f"/api/v1/projects/{project.id}/impact-report/"

    def test_admin_gets_impact_pdf(self, auth_client, admin_user, project):
        assert _is_pdf(auth_client(admin_user).get(self._url(project)))

    def test_manager_gets_impact_pdf(self, auth_client, manager_user, project):
        assert _is_pdf(auth_client(manager_user).get(self._url(project)))

    def test_donor_gets_impact_pdf(self, auth_client, donor_user, project):
        assert _is_pdf(auth_client(donor_user).get(self._url(project)))

    def test_assigned_officer_gets_impact_pdf(self, auth_client, officer_user, project):
        ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
        assert _is_pdf(auth_client(officer_user).get(self._url(project)))

    def test_officer_needs_assignment(self, auth_client, officer_user, project):
        # Same rule as everywhere else: unassigned -> not in queryset -> 404.
        assert auth_client(officer_user).get(self._url(project)).status_code == 404

    def test_no_cross_ngo_access(self, auth_client, donor_user, other_ngo):
        foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        assert auth_client(donor_user).get(self._url(foreign)).status_code == 404


class TestImpactPdfContent:
    def test_impact_pdf_embeds_photos_and_renders(
        self, ngo, officer_user, settings, tmp_path
    ):
        # Isolate uploaded files to a temp dir rather than the project media/.
        settings.MEDIA_ROOT = tmp_path
        from apps.common.pdf import donor_impact_pdf
        from apps.reports.models import ReportImage
        from apps.reports.services import post_report, project_impact_summary
        from apps.reports.tests.conftest import make_image_file

        p = Project.objects.create(project_name="Photo test", ngo=ngo, budget="1000.00")
        r = Report.objects.create(
            project=p, officer=officer_user, title="With photo",
            report_type="monthly", status=Report.Status.SUBMITTED,
            amount_spent="100.00", beneficiaries_reached=5,
        )
        post_report(r)  # approve + post so it reaches the impact roll-up
        ReportImage.objects.create(
            report=r, image=make_image_file("evidence.png"), caption="Site photo"
        )

        p.refresh_from_db()  # budget etc. as typed Decimals, as the view passes
        pdf = donor_impact_pdf(p, project_impact_summary(p))
        # A valid PDF that rendered the EVM + photo sections without error, and
        # is materially larger than an empty document (the embedded image).
        assert pdf[:4] == b"%PDF"
        assert len(pdf) > 2000


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
