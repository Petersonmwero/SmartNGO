"""Tests for the notify_due_milestones management command."""
from datetime import timedelta

import pytest
from django.core.management import call_command
from django.utils import timezone

from apps.notifications.models import Notification
from apps.projects.models import Milestone, Project, ProjectAssignment

pytestmark = pytest.mark.django_db


@pytest.fixture
def project_with_team(ngo, officer_user, manager_user):
    project = Project.objects.create(project_name="Teamed", ngo=ngo)
    ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    ProjectAssignment.objects.create(project=project, user=manager_user, role="manager")
    # Clear the "added to project" notifications the assignments generated.
    Notification.objects.all().delete()
    return project


def test_notifies_team_for_milestone_due_in_3_days(project_with_team, officer_user, manager_user):
    due = timezone.localdate() + timedelta(days=3)
    Milestone.objects.create(project=project_with_team, title="Survey", due_date=due, status="pending")

    call_command("notify_due_milestones")

    assert Notification.objects.filter(user=officer_user, title="Milestone due soon").count() == 1
    assert Notification.objects.filter(user=manager_user, title="Milestone due soon").count() == 1


def test_ignores_milestone_due_other_days(project_with_team):
    due = timezone.localdate() + timedelta(days=10)
    Milestone.objects.create(project=project_with_team, title="Far", due_date=due, status="pending")
    call_command("notify_due_milestones")
    assert Notification.objects.filter(title="Milestone due soon").count() == 0


def test_marks_overdue_milestones(project_with_team):
    past = timezone.localdate() - timedelta(days=1)
    m = Milestone.objects.create(project=project_with_team, title="Late", due_date=past, status="pending")
    call_command("notify_due_milestones")
    m.refresh_from_db()
    assert m.status == "overdue"


def test_custom_days_argument(project_with_team, officer_user):
    due = timezone.localdate() + timedelta(days=7)
    Milestone.objects.create(project=project_with_team, title="Wk", due_date=due, status="pending")
    call_command("notify_due_milestones", "--days", "7")
    assert Notification.objects.filter(title="Milestone due soon").count() == 2  # officer + manager
