"""Tests for indicator CRUD and read-only access for officers/donors."""
import pytest

from apps.projects.models import Project, ProjectAssignment

INDICATORS = "/api/v1/indicators/"

pytestmark = pytest.mark.django_db


@pytest.fixture
def assigned_project(ngo, officer_user):
    project = Project.objects.create(project_name="WASH", ngo=ngo)
    ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    return project


def _payload(project_id, **over):
    data = {
        "project": project_id,
        "indicator_name": "Wells dug",
        "target_value": "50",
        "current_value": "10",
        "unit": "wells",
    }
    data.update(over)
    return data


def test_manager_creates_and_progress_is_computed(auth_client, manager_user, ngo):
    project = Project.objects.create(project_name="P", ngo=ngo)
    resp = auth_client(manager_user).post(INDICATORS, _payload(project.id), format="json")
    assert resp.status_code == 201
    assert resp.data["progress_percent"] == 20.0  # 10/50


def test_officer_can_read_but_not_create(auth_client, officer_user, assigned_project):
    create = auth_client(officer_user).post(
        INDICATORS, _payload(assigned_project.id), format="json"
    )
    assert create.status_code == 403
    assert auth_client(officer_user).get(INDICATORS).status_code == 200


def test_donor_is_read_only(auth_client, donor_user, ngo):
    project = Project.objects.create(project_name="P", ngo=ngo)
    assert auth_client(donor_user).post(
        INDICATORS, _payload(project.id), format="json"
    ).status_code == 403
    assert auth_client(donor_user).get(INDICATORS).status_code == 200
