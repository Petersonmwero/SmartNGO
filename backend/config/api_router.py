"""
DRF router for the versioned API.

Top-level resources are registered on a DefaultRouter; nested sub-resources
(e.g. project assignments) are added as explicit paths since the project does
not depend on drf-nested-routers.
"""
from django.urls import path
from rest_framework.routers import DefaultRouter

from apps.beneficiaries.views import BeneficiaryViewSet
from apps.indicators.views import IndicatorViewSet
from apps.ngos.views import NGOViewSet
from apps.notifications.views import NotificationViewSet
from apps.projects.views import (
    MilestoneViewSet,
    ProjectAssignmentViewSet,
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

# Nested: /projects/<project_pk>/assignments/[<pk>/]
_assignment_list = ProjectAssignmentViewSet.as_view({"get": "list", "post": "create"})
_assignment_detail = ProjectAssignmentViewSet.as_view({"delete": "destroy"})

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
        "reports/<int:report_pk>/images/",
        _report_image_list,
        name="report-images",
    ),
    path(
        "reports/<int:report_pk>/images/<int:pk>/",
        _report_image_detail,
        name="report-image-detail",
    ),
    *router.urls,
]
