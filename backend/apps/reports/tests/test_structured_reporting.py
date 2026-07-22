"""Tests for structured donor reporting: approval-driven spend and milestone
posting, the validation rules around the new fields, and the project-level
aggregates they feed.

The governing rule throughout: figures count only once a report is approved,
and un-approving reverses exactly what the report itself posted.
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest

from apps.projects.models import Milestone, Project, ProjectPhase
from apps.reports.models import Report
from apps.reports.services import post_report, unpost_report

pytestmark = pytest.mark.django_db

REPORTS = "/api/v1/reports/"
TODAY = date.today()


def _project(ngo, budget="1000000.00"):
    return Project.objects.create(
        project_name="Structured Reporting Project",
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
        # Phase dates are required; the shared `assigned_project` fixture has
        # none, so fall back to a window around today.
        start_date=project.start_date or TODAY - timedelta(days=50),
        end_date=project.end_date or TODAY + timedelta(days=50),
    )


def _report(project, officer, status=Report.Status.SUBMITTED, **over):
    fields = {
        "project": project,
        "officer": officer,
        "title": "Borehole progress",
        "report_type": "weekly",
        "status": status,
        "amount_spent": Decimal("100000"),
    }
    fields.update(over)
    return Report.objects.create(**fields)


def _refetch(project):
    """Re-read so the cached phase/report prefetches are dropped."""
    return Project.objects.get(pk=project.pk)


# ── Spend posting ─────────────────────────────────────────────────────────
def test_only_approved_report_spend_counts(ngo, officer_user):
    """Draft and submitted spend is invisible; approving posts it."""
    project = _project(ngo)
    phase = _phase(project)
    draft = _report(project, officer_user, Report.Status.DRAFT, linked_phase=phase)
    submitted = _report(
        project, officer_user, Report.Status.SUBMITTED, linked_phase=phase
    )

    assert phase.spent_budget == Decimal("0")
    assert _refetch(project).financial_progress == 0.0

    post_report(submitted)
    phase.refresh_from_db()
    assert phase.reported_spend == Decimal("100000")
    assert phase.spent_budget == Decimal("100000")
    assert _refetch(project).financial_progress == 10.0

    # The draft still contributes nothing.
    assert draft.posted_at is None
    assert _refetch(project).total_spent == Decimal("100000")


def test_opening_spend_and_reported_spend_add_up(ngo, officer_user):
    """Baseline spend recorded before reporting still counts, plus the ledger."""
    project = _project(ngo)
    phase = _phase(project, opening="250000")
    post_report(_report(project, officer_user, linked_phase=phase))
    phase.refresh_from_db()
    assert phase.opening_spend == Decimal("250000")
    assert phase.reported_spend == Decimal("100000")
    assert phase.spent_budget == Decimal("350000")
    assert _refetch(project).financial_progress == 35.0


def test_approving_twice_does_not_double_count(ngo, officer_user):
    """Posting is idempotent — a repeat approval must not re-post the spend."""
    project = _project(ngo)
    phase = _phase(project)
    report = _report(project, officer_user, linked_phase=phase)

    assert post_report(report) is True
    first_posted_at = report.posted_at
    assert post_report(report) is False  # already posted

    report.refresh_from_db()
    assert report.posted_at == first_posted_at
    phase.refresh_from_db()
    assert phase.spent_budget == Decimal("100000")


def test_unapproving_removes_spend_and_reverts_its_milestone(ngo, officer_user):
    """Un-approving reverses both effects of the report's own posting."""
    project = _project(ngo)
    phase = _phase(project)
    milestone = Milestone.objects.create(project=project, title="Drilling done")
    report = _report(
        project, officer_user, linked_phase=phase, linked_milestone=milestone
    )

    post_report(report)
    milestone.refresh_from_db()
    assert milestone.status == Milestone.Status.COMPLETED
    assert milestone.completed_by_report_id == report.id

    unpost_report(report)
    phase.refresh_from_db()
    milestone.refresh_from_db()
    assert phase.reported_spend == Decimal("0")
    assert phase.spent_budget == Decimal("0")
    assert report.posted_at is None
    assert report.status == Report.Status.SUBMITTED
    assert milestone.status == Milestone.Status.PENDING
    assert milestone.completed_by_report is None


def test_unapproving_leaves_a_manually_completed_milestone_alone(ngo, officer_user):
    """A milestone ticked off by hand is not this report's to revert."""
    project = _project(ngo)
    milestone = Milestone.objects.create(
        project=project, title="Signed off by hand", status=Milestone.Status.COMPLETED
    )
    report = _report(project, officer_user, linked_milestone=milestone)

    post_report(report)
    milestone.refresh_from_db()
    # Posting left it alone too: it was already complete, so no ownership taken.
    assert milestone.completed_by_report is None

    unpost_report(report)
    milestone.refresh_from_db()
    assert milestone.status == Milestone.Status.COMPLETED
    assert milestone.completed_by_report is None


def test_linked_milestone_raises_physical_progress(ngo, officer_user):
    """A completed milestone moves physical progress by its weight share."""
    project = _project(ngo)
    target = Milestone.objects.create(project=project, title="Phase 1", weight=4)
    Milestone.objects.create(project=project, title="Phase 2", weight=6)
    assert _refetch(project).physical_progress == 0.0

    post_report(_report(project, officer_user, linked_milestone=target))
    assert _refetch(project).physical_progress == 40.0


# ── Validation ────────────────────────────────────────────────────────────
def test_links_from_another_project_are_rejected(auth_client, officer_user, ngo,
                                                 assigned_project):
    """A report cannot point at another project's phase or milestone."""
    other = _project(ngo)
    foreign_phase = _phase(other)
    foreign_milestone = Milestone.objects.create(project=other, title="Foreign")
    client = auth_client(officer_user)
    base = {
        "project": assigned_project.id,
        "title": "Cross-linked",
        "report_type": "daily",
    }

    resp = client.post(
        REPORTS, {**base, "linked_phase": foreign_phase.id}, format="json"
    )
    assert resp.status_code == 400
    # The global handler flattens field errors into a single "error" string.
    assert "linked_phase" in resp.data["error"]

    resp = client.post(
        REPORTS, {**base, "linked_milestone": foreign_milestone.id}, format="json"
    )
    assert resp.status_code == 400


def test_gender_split_cannot_exceed_total_reached(auth_client, officer_user,
                                                  assigned_project):
    """Male + female must fit inside the headline reached figure."""
    client = auth_client(officer_user)
    payload = {
        "project": assigned_project.id,
        "title": "Training day",
        "report_type": "daily",
        "beneficiaries_reached": 10,
        "beneficiaries_male": 6,
        "beneficiaries_female": 6,
    }
    assert client.post(REPORTS, payload, format="json").status_code == 400

    # Youth is a subset of the same total, not an addition to the split.
    payload.update({"beneficiaries_male": 4, "beneficiaries_female": 6,
                    "beneficiaries_youth": 11})
    assert client.post(REPORTS, payload, format="json").status_code == 400

    payload["beneficiaries_youth"] = 7
    assert client.post(REPORTS, payload, format="json").status_code == 201


def test_negative_amount_spent_rejected(auth_client, officer_user, assigned_project):
    resp = auth_client(officer_user).post(
        REPORTS,
        {
            "project": assigned_project.id,
            "title": "Negative",
            "report_type": "daily",
            "amount_spent": "-1.00",
        },
        format="json",
    )
    assert resp.status_code == 400


def test_approved_report_cannot_be_edited(auth_client, manager_user, ngo,
                                          officer_user, assigned_project):
    """Approved reports are frozen — corrections go in a new report."""
    report = _report(assigned_project, officer_user)
    post_report(report)
    resp = auth_client(manager_user).patch(
        f"{REPORTS}{report.id}/", {"amount_spent": "5.00"}, format="json"
    )
    assert resp.status_code == 400
    report.refresh_from_db()
    assert report.amount_spent == Decimal("100000")


# ── Project aggregates ────────────────────────────────────────────────────
def test_cost_per_beneficiary(ngo, officer_user):
    """Cost per beneficiary divides actual spend by people reached."""
    project = _project(ngo)
    phase = _phase(project)
    assert _refetch(project).cost_per_beneficiary is None  # nobody reached yet

    post_report(
        _report(
            project,
            officer_user,
            linked_phase=phase,
            amount_spent=Decimal("50000"),
            beneficiaries_reached=200,
        )
    )
    project = _refetch(project)
    assert project.beneficiaries_reached == 200
    assert project.reported_spend == Decimal("50000")
    assert project.cost_per_beneficiary == 250.0

    # A second approved report moves both sides of the ratio.
    post_report(
        _report(
            project,
            officer_user,
            linked_phase=phase,
            amount_spent=Decimal("30000"),
            beneficiaries_reached=100,
        )
    )
    assert _refetch(project).cost_per_beneficiary == pytest.approx(266.67)


def test_unapproved_reports_do_not_reach_beneficiary_totals(ngo, officer_user):
    """Only approved reports feed the reach figure."""
    project = _project(ngo)
    _report(project, officer_user, beneficiaries_reached=500)
    assert _refetch(project).beneficiaries_reached == 0
    assert _refetch(project).cost_per_beneficiary is None


# ── Backwards compatibility ───────────────────────────────────────────────
def test_legacy_report_without_structured_data_still_serializes(
    auth_client, officer_user, draft_report
):
    """Reports written before these fields existed keep working."""
    resp = auth_client(officer_user).get(f"{REPORTS}{draft_report.id}/")
    assert resp.status_code == 200
    assert resp.data["activity_type"] == ""
    assert resp.data["linked_phase"] is None
    assert resp.data["linked_milestone"] is None
    assert Decimal(resp.data["amount_spent"]) == Decimal("0")
    assert resp.data["beneficiaries_reached"] == 0
    assert resp.data["posted_at"] is None


def test_structured_fields_round_trip_through_the_api(auth_client, officer_user,
                                                      assigned_project):
    """A full structured payload saves and reads back."""
    phase = _phase(assigned_project)
    milestone = Milestone.objects.create(project=assigned_project, title="Handover")
    resp = auth_client(officer_user).post(
        REPORTS,
        {
            "project": assigned_project.id,
            "title": "Water point commissioned",
            "report_type": "monthly",
            "activity_type": "construction",
            "linked_phase": phase.id,
            "linked_milestone": milestone.id,
            "amount_spent": "125000.00",
            "expenditure_notes": "Pump and casing",
            "beneficiaries_reached": 300,
            "beneficiaries_male": 140,
            "beneficiaries_female": 160,
            "beneficiaries_youth": 90,
            "impact_description": "Walking time halved.",
            "challenges_faced": "Rain delayed casing.",
            "recommendations": "Fence the site.",
            "next_steps": "Train the committee.",
        },
        format="json",
    )
    assert resp.status_code == 201
    assert resp.data["activity_type"] == "construction"
    assert resp.data["linked_phase"] == phase.id
    assert resp.data["beneficiaries_youth"] == 90
    # Nothing posts until approval.
    assert resp.data["posted_at"] is None
    assert ProjectPhase.objects.get(pk=phase.pk).spent_budget == Decimal("0")


def test_approve_endpoint_posts_and_unapprove_reverses(auth_client, manager_user,
                                                       officer_user, ngo):
    """The workflow actions drive posting, not just the service functions."""
    project = Project.objects.create(
        project_name="Endpoint posting", ngo=ngo, budget=Decimal("1000000.00"),
        start_date=TODAY - timedelta(days=50), end_date=TODAY + timedelta(days=50),
    )
    phase = _phase(project)
    report = _report(project, officer_user, linked_phase=phase)
    client = auth_client(manager_user)

    resp = client.post(f"{REPORTS}{report.id}/approve/")
    assert resp.status_code == 200
    assert resp.data["status"] == "approved"
    assert resp.data["posted_at"] is not None
    assert ProjectPhase.objects.get(pk=phase.pk).spent_budget == Decimal("100000")

    resp = client.post(f"{REPORTS}{report.id}/unapprove/")
    assert resp.status_code == 200
    assert resp.data["status"] == "submitted"
    assert resp.data["posted_at"] is None
    assert ProjectPhase.objects.get(pk=phase.pk).spent_budget == Decimal("0")


def test_phase_api_exposes_the_spend_breakdown(auth_client, manager_user, ngo,
                                               officer_user):
    """Phase payloads carry baseline, reported, and actual spend."""
    project = _project(ngo)
    phase = _phase(project, opening="200000")
    post_report(_report(project, officer_user, linked_phase=phase))

    resp = auth_client(manager_user).get(f"/api/v1/projects/{project.id}/phases/")
    assert resp.status_code == 200
    rows = resp.data["results"] if "results" in resp.data else resp.data
    row = rows[0] if isinstance(rows, list) else rows["results"][0]
    assert Decimal(row["opening_spend"]) == Decimal("200000")
    assert Decimal(row["reported_spend"]) == Decimal("100000")
    assert Decimal(row["spent_budget"]) == Decimal("300000")


# ── Donor-grade completeness at submit ─────────────────────────────────────
def test_substantive_report_blocked_when_narrative_missing(
    auth_client, officer_user, assigned_project
):
    """A phase/milestone-linked report can't be submitted with gaps."""
    phase = _phase(assigned_project)
    report = _report(
        assigned_project, officer_user, status=Report.Status.DRAFT,
        linked_phase=phase, activity_type="construction",
        beneficiaries_reached=50, beneficiaries_male=20, beneficiaries_female=30,
        # impact_description and the other narrative fields left empty.
    )
    resp = auth_client(officer_user).post(f"{REPORTS}{report.id}/submit/")
    assert resp.status_code == 400
    report.refresh_from_db()
    assert report.status == Report.Status.DRAFT


def test_unlinked_report_submits_with_minimal_fields(
    auth_client, officer_user, assigned_project
):
    """A report with no phase/milestone link keeps the light rules."""
    report = _report(
        assigned_project, officer_user, status=Report.Status.DRAFT,
        activity_type="training",
    )
    resp = auth_client(officer_user).post(f"{REPORTS}{report.id}/submit/")
    assert resp.status_code == 200
    assert resp.data["status"] == "submitted"


def test_draft_with_gaps_still_saves(auth_client, officer_user, assigned_project):
    """Saving a linked draft with gaps is fine — the gate is only at submit."""
    phase = _phase(assigned_project)
    resp = auth_client(officer_user).post(
        REPORTS,
        {
            "project": assigned_project.id,
            "title": "Work in progress",
            "report_type": "weekly",
            "linked_phase": phase.id,
        },
        format="json",
    )
    assert resp.status_code == 201
    assert resp.data["status"] == "draft"


def test_complete_substantive_report_submits(
    auth_client, officer_user, assigned_project
):
    """A fully filled substantive report submits — mirrors seeded data."""
    phase = _phase(assigned_project)
    report = _report(
        assigned_project, officer_user, status=Report.Status.DRAFT,
        linked_phase=phase, activity_type="construction",
        beneficiaries_reached=50, beneficiaries_male=20, beneficiaries_female=30,
        impact_description="Walking time halved.",
        challenges_faced="Rain delayed casing.",
        recommendations="Fence the site.",
        next_steps="Train the committee.",
    )
    resp = auth_client(officer_user).post(f"{REPORTS}{report.id}/submit/")
    assert resp.status_code == 200
    assert resp.data["status"] == "submitted"
