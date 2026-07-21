"""Posting rules for approved reports.

Approving a report is what makes its figures count: spend joins the linked
phase's ledger and a linked milestone is marked complete. Un-approving undoes
exactly what the report itself posted — never anything a human did by hand.

`posted_at` (not `status`) is the ledger flag, so both operations are
idempotent: approving twice cannot post twice, and un-approving something that
never posted is a no-op.
"""
from decimal import Decimal

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


def project_impact_summary(project):
    """Roll up a project's approved reports into donor-facing figures.

    Only approved, posted reports count — the same rule the spend ledger
    uses — so nothing a manager has not signed off reaches a donor.

    Returns a dict of reach totals, spend, cost per beneficiary, a
    per-activity breakdown, and the narrative extracts, ready to serialize
    or render into a PDF.
    """
    reports = [
        r
        for r in project.reports.all()
        if r.status == Report.Status.APPROVED and r.posted_at is not None
    ]

    reach = {
        "total": sum(r.beneficiaries_reached for r in reports),
        "male": sum(r.beneficiaries_male for r in reports),
        "female": sum(r.beneficiaries_female for r in reports),
        "youth": sum(r.beneficiaries_youth for r in reports),
    }
    # Reports that recorded a reach figure but no gender split.
    reach["unspecified"] = max(reach["total"] - reach["male"] - reach["female"], 0)

    by_activity = {}
    for report in reports:
        key = report.activity_type or "unspecified"
        bucket = by_activity.setdefault(
            key,
            {
                "activity_type": key,
                "label": _activity_label(key),
                "reports": 0,
                "beneficiaries_reached": 0,
                "amount_spent": Decimal("0"),
            },
        )
        bucket["reports"] += 1
        bucket["beneficiaries_reached"] += report.beneficiaries_reached
        bucket["amount_spent"] += report.amount_spent

    narratives = [
        {
            "report_id": r.id,
            "title": r.title,
            "date": r.posted_at,
            "activity_label": _activity_label(r.activity_type or "unspecified"),
            "impact_description": r.impact_description,
            "challenges_faced": r.challenges_faced,
            "recommendations": r.recommendations,
            "next_steps": r.next_steps,
        }
        for r in reports
        if any(
            (
                r.impact_description,
                r.challenges_faced,
                r.recommendations,
                r.next_steps,
            )
        )
    ]

    return {
        "approved_reports": len(reports),
        "reach": reach,
        "reported_spend": sum((r.amount_spent for r in reports), Decimal("0")),
        "total_spent": project.total_spent,
        "cost_per_beneficiary": project.cost_per_beneficiary,
        "by_activity": sorted(
            by_activity.values(),
            key=lambda row: row["beneficiaries_reached"],
            reverse=True,
        ),
        "narratives": narratives,
    }


def _activity_label(value):
    """Display label for an activity type, including the synthetic bucket."""
    if value == "unspecified":
        return "Unspecified"
    return dict(Report.ActivityType.choices).get(value, value)
