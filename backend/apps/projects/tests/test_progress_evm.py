"""Tests for the Weighted Composite Progress Model (EVM).

Covers the three progress dimensions (financial / physical / time), the
composite formula, CPI/SPI performance indices, health thresholds, and the
nested project-phase CRUD API.
"""
from datetime import date, timedelta
from decimal import Decimal

import pytest

from apps.projects.models import Milestone, Project, ProjectPhase

pytestmark = pytest.mark.django_db

TODAY = date.today()


def _project(ngo, budget="1000000.00", start_offset=-50, end_offset=50):
    return Project.objects.create(
        project_name="EVM Test Project",
        ngo=ngo,
        budget=Decimal(budget),
        start_date=TODAY + timedelta(days=start_offset),
        end_date=TODAY + timedelta(days=end_offset),
    )


def _phase(project, allocated, spent, name="Phase"):
    return ProjectPhase.objects.create(
        project=project,
        phase_name=name,
        phase_type="implementation",
        allocated_budget=Decimal(allocated),
        spent_budget=Decimal(spent),
        start_date=project.start_date,
        end_date=project.end_date,
    )


def _milestone(project, weight, status="pending"):
    return Milestone.objects.create(
        project=project, title=f"M-{weight}-{status}", weight=weight, status=status
    )


# ── Dimension calculations ───────────────────────────────────────────────
def test_financial_progress_calculation(ngo):
    """Financial progress = sum of phase spend / total budget, capped at 100."""
    project = _project(ngo, budget="2400000.00")
    _phase(project, "400000", "400000", "Planning")
    _phase(project, "1200000", "928000", "Drilling")
    _phase(project, "800000", "400000", "Installation")
    assert project.total_spent == Decimal("1728000")
    assert project.budget_remaining == Decimal("672000")
    assert project.financial_progress == 72.0
    # Overspend beyond budget is capped at 100%.
    _phase(project, "1000000", "1000000", "Overrun")
    project = Project.objects.get(pk=project.pk)
    assert project.financial_progress == 100.0


def test_physical_progress_weighted(ngo):
    """Physical progress weights milestones by importance, not by count."""
    project = _project(ngo)
    _milestone(project, 2, "completed")
    _milestone(project, 1, "completed")
    _milestone(project, 4, "pending")
    _milestone(project, 3, "pending")
    _milestone(project, 2, "overdue")
    # 3 of 12 weight units delivered = 25% (a naive count would say 40%).
    assert project.physical_progress == 25.0


def test_time_progress_boundaries(ngo):
    """Time progress is 0 before start, 100 after end, proportional between."""
    not_started = _project(ngo, start_offset=10, end_offset=100)
    assert not_started.time_progress == 0.0
    finished = _project(ngo, start_offset=-100, end_offset=-10)
    assert finished.time_progress == 100.0
    halfway = _project(ngo, start_offset=-50, end_offset=50)
    assert halfway.time_progress == 50.0
    # Missing dates degrade to 0 rather than raising.
    undated = Project.objects.create(project_name="Undated", ngo=ngo)
    assert undated.time_progress == 0.0


def test_composite_progress_formula(ngo):
    """Composite = financial x 0.30 + physical x 0.50 + time x 0.20."""
    project = _project(ngo, budget="1000000.00", start_offset=-50, end_offset=50)
    _phase(project, "1000000", "720000")  # financial 72%
    _milestone(project, 1, "completed")
    _milestone(project, 3, "pending")  # physical 25%
    # time = 50%
    expected = round(72.0 * 0.30 + 25.0 * 0.50 + 50.0 * 0.20, 1)
    assert project.progress_percentage == expected == 44.1


def test_cpi_spi_calculations(ngo):
    """CPI = physical/financial, SPI = physical/time; None when undefined."""
    project = _project(ngo, budget="1000000.00", start_offset=-50, end_offset=50)
    _phase(project, "1000000", "400000")  # financial 40%
    _milestone(project, 1, "completed")
    _milestone(project, 1, "pending")  # physical 50%
    assert project.cost_performance_index == round(50.0 / 40.0, 2)
    assert project.schedule_performance_index == round(50.0 / 50.0, 2)
    # No spend -> CPI undefined; not yet started -> SPI undefined.
    unspent = _project(ngo, start_offset=5, end_offset=100)
    assert unspent.cost_performance_index is None
    assert unspent.schedule_performance_index is None


def test_health_status_thresholds(ngo):
    """healthy >= 0.95 on both, at_risk >= 0.8 on both, else critical."""
    def project_with(financial_spent, completed_weight, total_weight):
        p = _project(ngo, budget="1000000.00", start_offset=-50, end_offset=50)
        _phase(p, "1000000", financial_spent)
        if completed_weight:
            _milestone(p, completed_weight, "completed")
        _milestone(p, total_weight - completed_weight, "pending")
        return p

    # physical 50, financial 50, time 50 -> CPI 1.0, SPI 1.0.
    assert project_with("500000", 5, 10).health_status == "healthy"
    # physical 45, financial 50, time 50 -> CPI/SPI 0.9.
    assert project_with("500000", 45, 100).health_status == "at_risk"
    # physical 10, financial 50, time 50 -> CPI/SPI 0.2.
    assert project_with("500000", 10, 100).health_status == "critical"
    # No spend at all -> indices undefined -> not_started.
    assert _project(ngo).health_status == "not_started"


def test_zero_budget_edge_case(ngo):
    """Zero budget must not divide by zero anywhere."""
    project = Project.objects.create(
        project_name="Zero budget",
        ngo=ngo,
        budget=Decimal("0"),
        start_date=TODAY - timedelta(days=10),
        end_date=TODAY + timedelta(days=10),
    )
    _phase(project, "0", "0")
    assert project.financial_progress == 0.0
    assert project.cost_performance_index is None
    assert project.health_status == "not_started"
    assert project.progress_percentage == pytest.approx(
        round(project.time_progress * 0.20, 1)
    )
    # Zero allocation on the phase itself is also safe.
    assert project.phases.first().utilization_percentage == 0


def test_no_milestones_edge_case(ngo):
    """A project with no milestones has 0 physical progress, not an error."""
    project = _project(ngo, budget="1000000.00")
    _phase(project, "1000000", "500000")
    assert project.physical_progress == 0.0
    assert project.cost_performance_index == 0.0
    assert project.progress_percentage == round(
        50.0 * 0.30 + 0.0 * 0.50 + 50.0 * 0.20, 1
    )


# ── Phase API (nested under /projects/<id>/phases/) ──────────────────────
def _phases_url(project_id, phase_id=None):
    base = f"/api/v1/projects/{project_id}/phases/"
    return f"{base}{phase_id}/" if phase_id else base


def _phase_payload(**over):
    data = {
        "phase_name": "Drilling",
        "phase_type": "implementation",
        "allocated_budget": "1200000.00",
        "spent_budget": "928000.00",
        "start_date": str(TODAY - timedelta(days=30)),
        "end_date": str(TODAY + timedelta(days=30)),
        "status": "in_progress",
    }
    data.update(over)
    return data


def test_manager_creates_and_updates_phase(auth_client, manager_user, ngo):
    project = _project(ngo, budget="2400000.00")
    client = auth_client(manager_user)
    resp = client.post(_phases_url(project.id), _phase_payload(), format="json")
    assert resp.status_code == 201
    phase_id = resp.data["data"]["id"] if "data" in resp.data else resp.data["id"]
    # Updating spent_budget immediately moves the computed progress.
    resp = client.patch(
        _phases_url(project.id, phase_id), {"spent_budget": "1200000.00"},
        format="json",
    )
    assert resp.status_code == 200
    project = Project.objects.get(pk=project.pk)
    assert project.financial_progress == 50.0


def test_officer_reads_but_cannot_write_phases(auth_client, officer_user, ngo):
    project = _project(ngo)
    ProjectPhase.objects.create(
        project=project, phase_name="Planning", phase_type="planning",
        allocated_budget=Decimal("100"), start_date=TODAY, end_date=TODAY,
    )
    client = auth_client(officer_user)
    assert client.get(_phases_url(project.id)).status_code == 200
    assert client.post(
        _phases_url(project.id), _phase_payload(), format="json"
    ).status_code == 403


def test_phase_requires_auth_and_valid_project(api_client, auth_client,
                                               manager_user, other_ngo):
    assert api_client.get(_phases_url(1)).status_code == 401
    foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
    assert auth_client(manager_user).get(
        _phases_url(foreign.id)
    ).status_code == 403
    assert auth_client(manager_user).get(_phases_url(99999)).status_code == 404


def test_phase_rejects_bad_dates_and_negative_spend(auth_client, manager_user,
                                                    ngo):
    project = _project(ngo)
    client = auth_client(manager_user)
    bad_dates = _phase_payload(end_date=str(TODAY - timedelta(days=60)))
    assert client.post(
        _phases_url(project.id), bad_dates, format="json"
    ).status_code == 400
    negative = _phase_payload(spent_budget="-5.00")
    assert client.post(
        _phases_url(project.id), negative, format="json"
    ).status_code == 400


def test_milestone_weight_bounds(auth_client, manager_user, ngo):
    """Milestone weight is accepted in 1-10 and rejected outside it."""
    project = _project(ngo)
    client = auth_client(manager_user)
    payload = {"project": project.id, "title": "Weighted", "weight": 10}
    assert client.post("/api/v1/milestones/", payload,
                       format="json").status_code == 201
    payload["weight"] = 0
    assert client.post("/api/v1/milestones/", payload,
                       format="json").status_code == 400
    payload["weight"] = 11
    assert client.post("/api/v1/milestones/", payload,
                       format="json").status_code == 400
