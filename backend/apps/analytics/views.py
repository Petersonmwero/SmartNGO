"""Analytics endpoints — role-filtered aggregate stats and trend series."""
import calendar
from datetime import date
from decimal import Decimal

from django.db.models import Count, Q
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.accounts.models import Role
from apps.beneficiaries.models import Beneficiary
from apps.notifications.models import Notification
from apps.projects.models import Project
from apps.reports.models import Report
from core.responses import SuccessResponse

from .serializers import ReportSeriesSerializer


class AnalyticsDashboardView(APIView):
    """Return role-filtered aggregate statistics for the dashboard.

    Figures are scoped to the caller's NGO (manager/donor), to the caller's
    assigned projects (officer), or system-wide across every NGO (admin).

    Response shape:
      {status, message, data: {projects, beneficiaries, reports, notifications}}
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = user.role

        projects_qs = self._projects_qs(user, role)
        beneficiaries_qs = self._beneficiaries_qs(user, role, projects_qs)
        reports_qs = self._reports_qs(user, role, projects_qs)

        # Aggregate project counts by status in a single query.
        project_counts = projects_qs.aggregate(
            total=Count("id"),
            planning=Count("id", filter=Q(status=Project.Status.PLANNING)),
            active=Count("id", filter=Q(status=Project.Status.ACTIVE)),
            on_hold=Count("id", filter=Q(status=Project.Status.ON_HOLD)),
            completed=Count("id", filter=Q(status=Project.Status.COMPLETED)),
            cancelled=Count("id", filter=Q(status=Project.Status.CANCELLED)),
        )

        report_counts = reports_qs.aggregate(
            draft=Count("id", filter=Q(status=Report.Status.DRAFT)),
            submitted=Count("id", filter=Q(status=Report.Status.SUBMITTED)),
            approved=Count("id", filter=Q(status=Report.Status.APPROVED)),
        )

        unread_notifications = Notification.objects.filter(
            user=user, status=Notification.Status.UNREAD
        ).count()

        data = {
            "projects": {
                "total": project_counts["total"],
                "by_status": {
                    "planning": project_counts["planning"],
                    "active": project_counts["active"],
                    "on_hold": project_counts["on_hold"],
                    "completed": project_counts["completed"],
                    "cancelled": project_counts["cancelled"],
                },
            },
            "beneficiaries": {
                "total": beneficiaries_qs.count(),
            },
            "reports": {
                "draft": report_counts["draft"],
                "submitted": report_counts["submitted"],
                "approved": report_counts["approved"],
            },
            "notifications": {
                "unread": unread_notifications,
            },
        }

        return SuccessResponse(data=data)

    def _projects_qs(self, user, role):
        """Return the base Project queryset scoped by role."""
        if role == Role.ADMIN:
            # System-wide admin: every NGO, matching /projects/ and the
            # ProjectScopedViewSetMixin. Scoping admins to their own NGO here
            # made the dashboard count disagree with the project list beneath
            # it.
            return Project.objects.all()
        if role == Role.OFFICER:
            # Officers see only the projects they are assigned to.
            return Project.objects.filter(assignments__user=user).distinct()
        # Manager and Donor: all projects in their NGO.
        return Project.objects.filter(ngo=user.ngo)

    def _beneficiaries_qs(self, user, role, projects_qs):
        """Return active Beneficiary queryset scoped by the caller's projects."""
        return Beneficiary.objects.filter(
            project__in=projects_qs, is_active=True
        )

    def _reports_qs(self, user, role, projects_qs):
        """Return Report queryset scoped by role."""
        if role == Role.OFFICER:
            # Officers see only their own reports.
            return Report.objects.filter(officer=user)
        return Report.objects.filter(project__in=projects_qs)


class ReportSeriesView(APIView):
    """Monthly reporting activity for a trend chart.

    Returns a contiguous run of months ending with the current one, oldest
    first, so a chart can plot it without filling gaps itself — months with
    no reporting come back as zeros rather than being omitted.

    Bucketing is by `date_submitted`, i.e. when the work was reported, and a
    month's `approved` count is the subset of that month's submissions which
    have since been approved. Drafts have no submission date and are excluded
    entirely. Reach and spend come only from approved reports, matching every
    other donor-facing figure.

    Query params: `months` (1-24, default 6), `project_id` (optional).
    """

    permission_classes = [IsAuthenticated]

    DEFAULT_MONTHS = 6
    MAX_MONTHS = 24

    @extend_schema(
        parameters=[
            OpenApiParameter("months", OpenApiTypes.INT),
            OpenApiParameter("project_id", OpenApiTypes.INT),
        ],
        responses=ReportSeriesSerializer,
    )
    def get(self, request):
        months = self._months_param(request)
        reports = self._reports_qs(request.user, request.user.role)

        project_id = request.query_params.get("project_id")
        if project_id:
            try:
                reports = reports.filter(project_id=int(project_id))
            except (TypeError, ValueError):
                raise ValidationError("project_id must be an integer.")

        buckets = self._empty_buckets(months)
        earliest = date(buckets[0]["year"], buckets[0]["month"], 1)
        index = {(b["year"], b["month"]): b for b in buckets}

        for report in reports.filter(
            date_submitted__isnull=False, date_submitted__date__gte=earliest
        ).only(
            "date_submitted",
            "status",
            "posted_at",
            "beneficiaries_reached",
            "amount_spent",
        ):
            submitted_on = timezone.localtime(report.date_submitted)
            bucket = index.get((submitted_on.year, submitted_on.month))
            if bucket is None:
                continue  # submitted after "now" (clock skew); ignore
            bucket["submitted"] += 1
            if report.status == Report.Status.APPROVED and report.posted_at:
                bucket["approved"] += 1
                bucket["beneficiaries_reached"] += report.beneficiaries_reached
                bucket["amount_spent"] += report.amount_spent

        return SuccessResponse(
            data=ReportSeriesSerializer(
                {"months": months, "series": buckets}
            ).data
        )

    def _months_param(self, request):
        """Parse and bound the window length."""
        raw = request.query_params.get("months", self.DEFAULT_MONTHS)
        try:
            months = int(raw)
        except (TypeError, ValueError):
            raise ValidationError("months must be an integer.")
        if not 1 <= months <= self.MAX_MONTHS:
            raise ValidationError(
                f"months must be between 1 and {self.MAX_MONTHS}."
            )
        return months

    def _empty_buckets(self, months):
        """Zeroed buckets for the last `months` months, oldest first."""
        today = timezone.localdate()
        buckets = []
        for offset in range(months - 1, -1, -1):
            # Walk back whole months without a date library: subtract from a
            # zero-based month index so December wraps correctly.
            total = today.year * 12 + (today.month - 1) - offset
            year, month = divmod(total, 12)
            buckets.append(
                {
                    "year": year,
                    "month": month + 1,
                    "label": f"{calendar.month_abbr[month + 1]} {year}",
                    "submitted": 0,
                    "approved": 0,
                    "beneficiaries_reached": 0,
                    "amount_spent": Decimal("0"),
                }
            )
        return buckets

    # Role scoping is identical to the dashboard's, so it is reused rather
    # than restated — the two must never disagree about what a user can see.
    _projects_qs = AnalyticsDashboardView._projects_qs

    def _reports_qs(self, user, role):
        return AnalyticsDashboardView._reports_qs(
            self, user, role, self._projects_qs(user, role)
        )
