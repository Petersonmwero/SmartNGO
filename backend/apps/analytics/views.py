"""Analytics dashboard endpoint — role-filtered aggregate stats."""
from django.db.models import Count, Q
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.accounts.models import Role
from apps.beneficiaries.models import Beneficiary
from apps.notifications.models import Notification
from apps.projects.models import Project
from apps.reports.models import Report
from core.responses import SuccessResponse


class AnalyticsDashboardView(APIView):
    """Return role-filtered aggregate statistics for the dashboard.

    All figures are scoped to the caller's NGO (admin/manager/donor) or to
    the caller's assigned projects (officer).

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
            # Admin sees all projects in their NGO.
            return Project.objects.filter(ngo=user.ngo)
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
