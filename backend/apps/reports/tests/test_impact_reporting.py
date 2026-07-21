"""Tests for the donor-facing impact roll-up and its PDF.

The rule under test throughout: a donor sees approved work only. Drafts and
submitted-but-unapproved reports must never appear in a reach figure, a
spend total, or a narrative extract.
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest

from apps.projects.models import Project, ProjectPhase
from apps.reports.models import Report
from apps.reports.services import post_report, project_impact_summary

pytestmark = pytest.mark.django_db

TODAY = date.today()


def _project(ngo, budget="1000000.00"):
    return Project.objects.create(
        project_name="Impact Project",
        ngo=ngo,
        budget=Decimal(budget),
        start_date=TODAY - timedelta(days=50),
        end_date=TODAY + timedelta(days=50),
    )


def _phase(project, allocated="1000000", opening="0"):
    return ProjectPhase.objects.create(
        project=project,
        phase_name="Implementation",
        phase_type="implementation",
        allocated_budget=Decimal(allocated),
        opening_spend=Decimal(opening),
        start_date=project.start_date,
        end_date=project.end_date,
    )


def _report(project, officer, **over):
    fields = {
        "project": project,
        "officer": officer,
        "title": "Training day",
        "report_type": "weekly",
        "status": Report.Status.SUBMITTED,
        "activity_type": "training",
        "amount_spent": Decimal("50000"),
        "beneficiaries_reached": 100,
        "beneficiaries_male": 40,
        "beneficiaries_female": 60,
        "beneficiaries_youth": 30,
    }
    fields.update(over)
    return Report.objects.create(**fields)


def _summary(project):
    return project_impact_summary(Project.objects.get(pk=project.pk))


def test_summary_counts_only_approved_reports(ngo, officer_user):
    project = _project(ngo)
    phase = _phase(project)
    _report(project, officer_user, status=Report.Status.DRAFT)
    unapproved = _report(project, officer_user, title="Awaiting sign-off")
    approved = _report(project, officer_user, title="Signed off", linked_phase=phase)
    post_report(approved)

    summary = _summary(project)
    assert summary["approved_reports"] == 1
    assert summary["reach"]["total"] == 100
    assert summary["reported_spend"] == Decimal("50000")
    assert unapproved.posted_at is None


def test_reach_splits_and_unspecified_remainder(ngo, officer_user):
    """Reports that give a total but no split leave a remainder bucket."""
    project = _project(ngo)
    post_report(_report(project, officer_user))  # 100: 40 m, 60 f, 30 youth
    post_report(
        _report(
            project,
            officer_user,
            title="Headcount only",
            beneficiaries_reached=50,
            beneficiaries_male=0,
            beneficiaries_female=0,
            beneficiaries_youth=0,
        )
    )
    reach = _summary(project)["reach"]
    assert reach["total"] == 150
    assert reach["male"] == 40
    assert reach["female"] == 60
    assert reach["youth"] == 30
    assert reach["unspecified"] == 50


def test_activity_breakdown_groups_and_ranks(ngo, officer_user):
    """Activities are grouped, labelled, and ordered by people reached."""
    project = _project(ngo)
    post_report(_report(project, officer_user))  # training, 100
    post_report(_report(project, officer_user, title="Second training"))  # 100
    post_report(
        _report(
            project,
            officer_user,
            title="Handover",
            activity_type="construction",
            beneficiaries_reached=400,
        )
    )
    post_report(
        _report(
            project,
            officer_user,
            title="Unlabelled visit",
            activity_type="",
            beneficiaries_reached=10,
        )
    )

    rows = _summary(project)["by_activity"]
    assert [r["activity_type"] for r in rows] == [
        "construction",
        "training",
        "unspecified",
    ]
    training = next(r for r in rows if r["activity_type"] == "training")
    assert training["reports"] == 2
    assert training["beneficiaries_reached"] == 200
    assert training["amount_spent"] == Decimal("100000")
    assert rows[0]["label"] == "Construction"
    assert rows[-1]["label"] == "Unspecified"


def test_narratives_only_include_reports_with_something_to_say(ngo, officer_user):
    project = _project(ngo)
    post_report(_report(project, officer_user, title="Numbers only"))
    post_report(
        _report(
            project,
            officer_user,
            title="With a story",
            impact_description="Attendance doubled.",
            challenges_faced="Rain.",
        )
    )
    narratives = _summary(project)["narratives"]
    assert [n["title"] for n in narratives] == ["With a story"]
    assert narratives[0]["impact_description"] == "Attendance doubled."
    assert narratives[0]["activity_label"] == "Training"


def test_cost_per_beneficiary_uses_actual_spend(ngo, officer_user):
    """Baseline phase spend counts too, not just report spend."""
    project = _project(ngo)
    phase = _phase(project, opening="20000")
    post_report(_report(project, officer_user, linked_phase=phase))

    summary = _summary(project)
    assert summary["total_spent"] == Decimal("70000")  # 20k baseline + 50k
    assert summary["reported_spend"] == Decimal("50000")
    assert summary["cost_per_beneficiary"] == 700.0


def test_empty_project_summary_is_safe(ngo):
    """A project with no reports yields zeros, not an error."""
    summary = _summary(_project(ngo))
    assert summary["approved_reports"] == 0
    assert summary["reach"]["total"] == 0
    assert summary["cost_per_beneficiary"] is None
    assert summary["by_activity"] == []
    assert summary["narratives"] == []


# ── API ───────────────────────────────────────────────────────────────────
def test_impact_summary_endpoint(auth_client, manager_user, ngo, officer_user):
    project = _project(ngo)
    phase = _phase(project)
    post_report(_report(project, officer_user, linked_phase=phase))

    resp = auth_client(manager_user).get(
        f"/api/v1/projects/{project.id}/impact-summary/"
    )
    assert resp.status_code == 200
    data = resp.data["data"] if "data" in resp.data else resp.data
    assert data["approved_reports"] == 1
    assert data["reach"]["total"] == 100
    assert data["reach"]["female"] == 60
    assert data["by_activity"][0]["label"] == "Training"
    assert float(data["cost_per_beneficiary"]) == 500.0


def test_donor_can_read_impact_but_not_another_ngos(auth_client, donor_user, ngo,
                                                    other_ngo, officer_user):
    """Donors are the audience for this, but stay inside their own NGO."""
    project = _project(ngo)
    post_report(_report(project, officer_user))
    foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)

    client = auth_client(donor_user)
    assert client.get(
        f"/api/v1/projects/{project.id}/impact-summary/"
    ).status_code == 200
    assert client.get(
        f"/api/v1/projects/{foreign.id}/impact-summary/"
    ).status_code == 404


def test_impact_summary_requires_auth(api_client, ngo):
    project = _project(ngo)
    assert api_client.get(
        f"/api/v1/projects/{project.id}/impact-summary/"
    ).status_code == 401


def test_impact_report_pdf(auth_client, donor_user, ngo, officer_user):
    """The PDF renders and is served as a download."""
    project = _project(ngo)
    phase = _phase(project, opening="20000")
    post_report(
        _report(
            project,
            officer_user,
            linked_phase=phase,
            impact_description="Attendance doubled.",
        )
    )

    resp = auth_client(donor_user).get(
        f"/api/v1/projects/{project.id}/impact-report/"
    )
    assert resp.status_code == 200
    assert resp["Content-Type"] == "application/pdf"
    assert f"project_{project.id}_impact.pdf" in resp["Content-Disposition"]
    assert resp.content.startswith(b"%PDF")


def test_impact_report_pdf_with_no_reports(auth_client, manager_user, ngo):
    """An empty project still produces a valid PDF rather than failing."""
    project = _project(ngo)
    resp = auth_client(manager_user).get(
        f"/api/v1/projects/{project.id}/impact-report/"
    )
    assert resp.status_code == 200
    assert resp.content.startswith(b"%PDF")
