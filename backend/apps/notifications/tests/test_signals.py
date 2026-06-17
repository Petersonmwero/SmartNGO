"""Tests for notification-emitting signals."""
import pytest

from apps.notifications.models import Notification
from apps.projects.models import Project, ProjectAssignment
from apps.reports.models import Report

pytestmark = pytest.mark.django_db


@pytest.fixture
def project(ngo):
    return Project.objects.create(project_name="Signals Project", ngo=ngo)


def test_assignment_created_notifies_user(project, officer_user):
    ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    notes = Notification.objects.filter(user=officer_user, title="Added to a project")
    assert notes.count() == 1
    assert project.project_name in notes.first().message


def test_assignment_removed_notifies_user(project, officer_user):
    a = ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    Notification.objects.filter(user=officer_user).delete()  # clear the "added" note
    a.delete()
    assert Notification.objects.filter(
        user=officer_user, title="Removed from a project"
    ).count() == 1


def test_report_approval_notifies_author(project, officer_user):
    report = Report.objects.create(
        project=project, officer=officer_user, title="R1", report_type="daily",
        status=Report.Status.SUBMITTED,
    )
    assert not Notification.objects.filter(title="Report approved").exists()

    report.status = Report.Status.APPROVED
    report.save(update_fields=["status"])

    notes = Notification.objects.filter(user=officer_user, title="Report approved")
    assert notes.count() == 1


def test_no_duplicate_approval_notification(project, officer_user):
    report = Report.objects.create(
        project=project, officer=officer_user, title="R1", report_type="daily",
        status=Report.Status.SUBMITTED,
    )
    report.status = Report.Status.APPROVED
    report.save(update_fields=["status"])
    # Saving again while already approved must not re-notify.
    report.save(update_fields=["status"])
    assert Notification.objects.filter(title="Report approved").count() == 1


def test_draft_report_creation_does_not_notify(project, officer_user):
    Report.objects.create(
        project=project, officer=officer_user, title="R1", report_type="daily"
    )
    assert not Notification.objects.filter(title="Report approved").exists()
