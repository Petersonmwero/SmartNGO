"""Posting rules for approved reports.

Approving a report is what makes its figures count: spend joins the linked
phase's ledger and a linked milestone is marked complete. Un-approving undoes
exactly what the report itself posted — never anything a human did by hand.

`posted_at` (not `status`) is the ledger flag, so both operations are
idempotent: approving twice cannot post twice, and un-approving something that
never posted is a no-op.
"""
from django.db import transaction
from django.utils import timezone

from apps.projects.models import Milestone

from .models import Report


@transaction.atomic
def post_report(report):
    """Mark a report posted and apply its milestone effect.

    Returns True when this call posted the report, False when it had already
    been posted (so callers can tell a real approval from a repeat).
    """
    if report.posted_at is not None:
        return False

    report.posted_at = timezone.now()
    report.status = Report.Status.APPROVED
    report.save(update_fields=["posted_at", "status"])

    milestone = report.linked_milestone
    if milestone is not None and milestone.status != Milestone.Status.COMPLETED:
        milestone.status = Milestone.Status.COMPLETED
        milestone.completed_by_report = report
        milestone.save(update_fields=["status", "completed_by_report"])
    return True


@transaction.atomic
def unpost_report(report, status=Report.Status.SUBMITTED):
    """Reverse a posted report, returning it to `status`.

    A linked milestone is reverted only when this report is the one that
    completed it; a milestone completed manually (or by a different report)
    is left alone.
    """
    if report.posted_at is None:
        report.status = status
        report.save(update_fields=["status"])
        return False

    report.posted_at = None
    report.status = status
    report.save(update_fields=["posted_at", "status"])

    milestone = report.linked_milestone
    if milestone is not None and milestone.completed_by_report_id == report.id:
        milestone.status = Milestone.Status.PENDING
        milestone.completed_by_report = None
        milestone.save(update_fields=["status", "completed_by_report"])
    return True
