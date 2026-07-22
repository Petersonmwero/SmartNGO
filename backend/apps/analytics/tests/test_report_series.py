"""Tests for GET /api/v1/analytics/reports-series/ — monthly trend data."""
from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.projects.models import Project, ProjectAssignment
from apps.reports.models import Report
from apps.reports.services import post_report

SERIES = "/api/v1/analytics/reports-series/"

pytestmark = pytest.mark.django_db


@pytest.fixture
def project(ngo):
    return Project.objects.create(project_name="Nutrition", ngo=ngo, status="active")


def _months_ago(months):
    """A timestamp roughly `months` calendar months back, mid-month.

    Anchored to the 15th so the result cannot slip into a neighbouring month
    on long/short months — the buckets are what is under test, not date
    arithmetic.
    """
    today = timezone.localdate().replace(day=15)
    total = today.year * 12 + (today.month - 1) - months
    year, month = divmod(total, 12)
    naive = timezone.datetime(year, month + 1, 15, 12, 0)
    return timezone.make_aware(naive)


def _report(project, officer, *, submitted_ago, approved=False, **over):
    fields = {
        "project": project,
        "officer": officer,
        "title": f"Report {submitted_ago} months ago",
        "report_type": "monthly",
        "status": Report.Status.SUBMITTED,
        "date_submitted": _months_ago(submitted_ago),
    }
    fields.update(over)
    report = Report.objects.create(**fields)
    if approved:
        post_report(report)
    return report


def _series(resp):
    data = resp.data["data"] if "data" in resp.data else resp.data
    return data["series"]


def test_returns_six_contiguous_months_oldest_first(auth_client, manager_user):
    resp = auth_client(manager_user).get(SERIES)
    assert resp.status_code == 200
    series = _series(resp)
    assert len(series) == 6

    # Oldest first, contiguous, ending with the current month.
    today = timezone.localdate()
    assert (series[-1]["year"], series[-1]["month"]) == (today.year, today.month)
    for earlier, later in zip(series, series[1:]):
        gap = (later["year"] * 12 + later["month"]) - (
            earlier["year"] * 12 + earlier["month"]
        )
        assert gap == 1


def test_quiet_months_are_zeros_not_gaps(auth_client, manager_user, officer_user,
                                         project):
    """A chart must be able to plot the run without filling holes itself."""
    _report(project, officer_user, submitted_ago=2)
    series = _series(auth_client(manager_user).get(SERIES))

    assert [point["submitted"] for point in series] == [0, 0, 0, 1, 0, 0]
    assert all(point["label"] for point in series)


def test_approved_subset_reach_and_spend(auth_client, manager_user,
                                         officer_user, project):
    """Approved counts, reach and spend all key off the same month."""
    _report(
        project,
        officer_user,
        submitted_ago=1,
        approved=True,
        beneficiaries_reached=120,
        amount_spent=Decimal("45000"),
    )
    _report(project, officer_user, submitted_ago=1)  # submitted, not approved
    series = _series(auth_client(manager_user).get(SERIES))
    last_month = series[-2]

    assert last_month["submitted"] == 2
    assert last_month["approved"] == 1
    assert last_month["beneficiaries_reached"] == 120
    assert Decimal(last_month["amount_spent"]) == Decimal("45000.00")


def test_drafts_are_excluded(auth_client, manager_user, officer_user, project):
    """Drafts have no submission date, so they cannot be placed on a month."""
    Report.objects.create(
        project=project,
        officer=officer_user,
        title="Never submitted",
        report_type="daily",
        status=Report.Status.DRAFT,
    )
    series = _series(auth_client(manager_user).get(SERIES))
    assert sum(point["submitted"] for point in series) == 0


def test_reports_older_than_the_window_fall_out(auth_client, manager_user,
                                                officer_user, project):
    _report(project, officer_user, submitted_ago=8)
    assert sum(p["submitted"] for p in
               _series(auth_client(manager_user).get(SERIES))) == 0
    # Widening the window brings it back.
    resp = auth_client(manager_user).get(SERIES, {"months": 12})
    assert sum(p["submitted"] for p in _series(resp)) == 1


def test_months_parameter_is_bounded(auth_client, manager_user):
    client = auth_client(manager_user)
    assert len(_series(client.get(SERIES, {"months": 1}))) == 1
    assert len(_series(client.get(SERIES, {"months": 24}))) == 24
    assert client.get(SERIES, {"months": 0}).status_code == 400
    assert client.get(SERIES, {"months": 25}).status_code == 400
    assert client.get(SERIES, {"months": "six"}).status_code == 400


def test_project_filter(auth_client, manager_user, officer_user, ngo, project):
    other = Project.objects.create(project_name="Other", ngo=ngo)
    _report(project, officer_user, submitted_ago=0)
    _report(other, officer_user, submitted_ago=0)

    client = auth_client(manager_user)
    assert sum(p["submitted"] for p in _series(client.get(SERIES))) == 2
    resp = client.get(SERIES, {"project_id": project.id})
    assert sum(p["submitted"] for p in _series(resp)) == 1
    assert client.get(SERIES, {"project_id": "abc"}).status_code == 400


def test_scoping_matches_the_dashboard(auth_client, manager_user, officer_user,
                                       donor_user, other_ngo, ngo, project):
    """Same role rules as the dashboard: NGO for manager/donor, own reports
    for officers, and nothing from another NGO."""
    foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
    foreign_officer = officer_user  # reused; the project is what differs
    _report(foreign, foreign_officer, submitted_ago=0)
    _report(project, officer_user, submitted_ago=0)

    manager_total = sum(
        p["submitted"] for p in _series(auth_client(manager_user).get(SERIES))
    )
    donor_total = sum(
        p["submitted"] for p in _series(auth_client(donor_user).get(SERIES))
    )
    assert manager_total == 1  # only the report in their own NGO
    assert donor_total == 1

    # An officer with no assignment still sees their own reports.
    officer_total = sum(
        p["submitted"] for p in _series(auth_client(officer_user).get(SERIES))
    )
    assert officer_total == 2

    ProjectAssignment.objects.create(
        project=project, user=officer_user, role="officer"
    )
    assert sum(
        p["submitted"] for p in _series(auth_client(officer_user).get(SERIES))
    ) == 2


def test_requires_authentication(api_client):
    assert api_client.get(SERIES).status_code == 401


def test_month_labels_wrap_the_year(auth_client, manager_user):
    """Walking back across January must not produce month 0."""
    resp = auth_client(manager_user).get(SERIES, {"months": 24})
    series = _series(resp)
    assert all(1 <= point["month"] <= 12 for point in series)
    assert len({(p["year"], p["month"]) for p in series}) == 24


def test_report_submitted_this_month_lands_in_the_last_bucket(
    auth_client, manager_user, officer_user, project
):
    Report.objects.create(
        project=project,
        officer=officer_user,
        title="Today",
        report_type="daily",
        status=Report.Status.SUBMITTED,
        date_submitted=timezone.now() - timedelta(minutes=5),
    )
    series = _series(auth_client(manager_user).get(SERIES))
    assert series[-1]["submitted"] == 1
