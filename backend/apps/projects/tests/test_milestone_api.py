"""Tests for milestone CRUD (managed by admin/manager, read-only for others)."""
import pytest

from apps.projects.models import Project, ProjectAssignment

MILESTONES = "/api/v1/milestones/"

pytestmark = pytest.mark.django_db


def _payload(project_id, **over):
    data = {
        "project": project_id,
        "title": "Baseline survey",
        "description": "Complete baseline",
        "due_date": "2026-09-01",
        "status": "pending",
    }
    data.update(over)
    return data


def test_manager_creates_milestone(auth_client, manager_user, ngo):
    project = Project.objects.create(project_name="P", ngo=ngo)
    resp = auth_client(manager_user).post(MILESTONES, _payload(project.id), format="json")
    assert resp.status_code == 201


def test_officer_cannot_create_but_can_read(auth_client, officer_user, ngo):
    project = Project.objects.create(project_name="P", ngo=ngo)
    ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    assert auth_client(officer_user).post(
        MILESTONES, _payload(project.id), format="json"
    ).status_code == 403
    assert auth_client(officer_user).get(MILESTONES).status_code == 200


def test_manager_blocked_on_other_ngo(auth_client, manager_user, other_ngo):
    foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
    assert auth_client(manager_user).post(
        MILESTONES, _payload(foreign.id), format="json"
    ).status_code == 403


def test_filter_by_status(auth_client, manager_user, ngo):
    project = Project.objects.create(project_name="P", ngo=ngo)
    from apps.projects.models import Milestone

    Milestone.objects.create(project=project, title="Done", status="completed")
    Milestone.objects.create(project=project, title="Todo", status="pending")
    resp = auth_client(manager_user).get(MILESTONES, {"status": "completed"})
    assert {m["title"] for m in resp.data["results"]} == {"Done"}
