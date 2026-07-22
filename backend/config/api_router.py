"""
DRF router for the versioned API.

Top-level resources are registered on a DefaultRouter; nested sub-resources
(e.g. project assignments) are added as explicit paths since the project does
not depend on drf-nested-routers.
"""
from django.urls import path
from rest_framework.routers import DefaultRouter

from apps.accounts.views import UserManagementViewSet
from apps.analytics.views import AnalyticsDashboardView, ReportSeriesView
from apps.beneficiaries.views import BeneficiaryViewSet, KenyaLocationView
from apps.indicators.views import IndicatorViewSet
from apps.ngos.views import NGOViewSet
from apps.notifications.views import NotificationViewSet
from apps.projects.views import (
    MilestoneViewSet,
    ProjectAssignmentViewSet,
    ProjectPhaseViewSet,
    ProjectViewSet,
)
from apps.reports.views import ReportImageViewSet, ReportViewSet

router = DefaultRouter()
router.register("ngos", NGOViewSet, basename="ngo")
router.register("projects", ProjectViewSet, basename="project")
router.register("beneficiaries", BeneficiaryViewSet, basename="beneficiary")
router.register("indicators", IndicatorViewSet, basename="indicator")
router.register("milestones", MilestoneViewSet, basename="milestone")
router.register("reports", ReportViewSet, basename="report")
router.register("notifications", NotificationViewSet, basename="notification")
router.register("users", UserManagementViewSet, basename="user")

# Nested: /projects/<project_pk>/assignments/[<pk>/]
_assignment_list = ProjectAssignmentViewSet.as_view({"get": "list", "post": "create"})
_assignment_detail = ProjectAssignmentViewSet.as_view({"delete": "destroy"})

# Nested: /projects/<project_pk>/phases/[<pk>/]
_phase_list = ProjectPhaseViewSet.as_view({"get": "list", "post": "create"})
_phase_detail = ProjectPhaseViewSet.as_view(
    {
        "get": "retrieve",
        "put": "update",
        "patch": "partial_update",
        "delete": "destroy",
    }
)

# Nested: /reports/<report_pk>/images/[<pk>/]
_report_image_list = ReportImageViewSet.as_view({"get": "list", "post": "create"})
_report_image_detail = ReportImageViewSet.as_view({"delete": "destroy"})

urlpatterns = [
    path(
        "projects/<int:project_pk>/assignments/",
        _assignment_list,
        name="project-assignments",
    ),
    path(
        "projects/<int:project_pk>/assignments/<int:pk>/",
        _assignment_detail,
        name="project-assignment-detail",
    ),
    path(
        "projects/<int:project_pk>/phases/",
        _phase_list,
        name="project-phases",
    ),
    path(
        "projects/<int:project_pk>/phases/<int:pk>/",
        _phase_detail,
        name="project-phase-detail",
    ),
    path(
        "reports/<int:report_pk>/images/",
        _report_image_list,
        name="report-images",
    ),
    path(
        "reports/<int:report_pk>/images/<int:pk>/",
        _report_image_detail,
        name="report-image-detail",
    ),
    path("analytics/dashboard/", AnalyticsDashboardView.as_view(), name="analytics-dashboard"),
    path("analytics/reports-series/", ReportSeriesView.as_view(), name="analytics-reports-series"),
    path("locations/kenya/", KenyaLocationView.as_view(), name="kenya-locations"),
    *router.urls,
]
