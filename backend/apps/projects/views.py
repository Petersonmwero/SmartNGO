"""Project CRUD and the nested project-assignments sub-resource."""
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated

from apps.accounts.models import Role
from apps.accounts.permissions import IsProjectManager, IsSystemAdmin
from apps.common.mixins import ProjectScopedViewSetMixin
from apps.common.pdf import monthly_report_pdf, project_summary_pdf

from .filters import MilestoneFilter, ProjectFilter
from .models import Milestone, Project, ProjectAssignment, ProjectPhase
from .serializers import (
    MilestoneSerializer,
    ProjectAssignmentSerializer,
    ProjectPhaseSerializer,
    ProjectSerializer,
)

# Admin or manager may mutate; everyone authenticated may read (further narrowed
# by get_queryset).
WRITE_PERMISSION = IsSystemAdmin | IsProjectManager


class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class = ProjectSerializer
    filterset_class = ProjectFilter
    queryset = Project.objects.none()  # for schema model derivation; see get_queryset

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy"):
            return [WRITE_PERMISSION()]
        return [IsAuthenticated()]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Project.objects.none()
        user = self.request.user
        # phases/milestones feed the computed progress properties on every
        # serialized row — prefetch them to avoid N+1 queries on list views.
        qs = (
            Project.objects.select_related("ngo")
            .prefetch_related("phases", "milestones")
            .order_by("-created_at")
        )
        if user.role == Role.ADMIN:
            return qs
        if user.role == Role.OFFICER:
            # Officers see only the projects they are assigned to.
            return qs.filter(assignments__user=user).distinct()
        # Managers and donors are scoped to their own NGO.
        return qs.filter(ngo_id=user.ngo_id)

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == Role.ADMIN:
            if not serializer.validated_data.get("ngo"):
                raise ValidationError({"ngo": "This field is required for admins."})
            serializer.save()
        else:
            # Managers can only create projects within their own NGO.
            serializer.save(ngo=user.ngo)

    # --- PDF generation (access scoped by get_queryset / get_object) -------
    @extend_schema(responses={(200, "application/pdf"): OpenApiTypes.BINARY})
    @action(detail=True, methods=["get"], url_path="summary-pdf")
    def summary_pdf(self, request, pk=None):
        """Donor-facing project summary as a PDF."""
        project = self.get_object()
        pdf = project_summary_pdf(project)
        response = HttpResponse(pdf, content_type="application/pdf")
        response["Content-Disposition"] = (
            f'attachment; filename="project_{project.id}_summary.pdf"'
        )
        return response

    @extend_schema(
        parameters=[
            OpenApiParameter("year", OpenApiTypes.INT),
            OpenApiParameter("month", OpenApiTypes.INT),
        ],
        responses={(200, "application/pdf"): OpenApiTypes.BINARY},
    )
    @action(detail=True, methods=["get"], url_path="monthly-report")
    def monthly_report(self, request, pk=None):
        """Monthly report of approved reports as a PDF (defaults to this month)."""
        project = self.get_object()
        today = timezone.localdate()
        try:
            year = int(request.query_params.get("year", today.year))
            month = int(request.query_params.get("month", today.month))
        except (TypeError, ValueError):
            raise ValidationError("year and month must be integers.")
        if not 1 <= month <= 12:
            raise ValidationError("month must be between 1 and 12.")

        pdf = monthly_report_pdf(project, year, month)
        response = HttpResponse(pdf, content_type="application/pdf")
        response["Content-Disposition"] = (
            f'attachment; filename="project_{project.id}_{year}_{month:02d}.pdf"'
        )
        return response


class ProjectAssignmentViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Assign/unassign managers and officers to a project.

    Routed at /api/v1/projects/<project_pk>/assignments/.
    """

    serializer_class = ProjectAssignmentSerializer
    queryset = ProjectAssignment.objects.none()  # for schema model derivation

    def get_permissions(self):
        if self.action in ("create", "destroy"):
            return [WRITE_PERMISSION()]
        return [IsAuthenticated()]

    def get_project(self):
        project = get_object_or_404(Project, pk=self.kwargs["project_pk"])
        user = self.request.user
        # Non-admins may only touch assignments for projects in their own NGO.
        if user.role != Role.ADMIN and project.ngo_id != user.ngo_id:
            raise PermissionDenied("You do not have access to this project.")
        return project

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ProjectAssignment.objects.none()
        return ProjectAssignment.objects.filter(
            project=self.get_project()
        ).select_related("user")

    def perform_create(self, serializer):
        project = self.get_project()
        user = serializer.validated_data["user"]
        if user.ngo_id != project.ngo_id:
            raise ValidationError("User must belong to the project's NGO.")
        if ProjectAssignment.objects.filter(project=project, user=user).exists():
            raise ValidationError("User is already assigned to this project.")
        serializer.save(project=project)


class ProjectPhaseViewSet(viewsets.ModelViewSet):
    """Budget phases of a project (nested sub-resource).

    Routed at /api/v1/projects/<project_pk>/phases/. Reads are open to any
    authenticated user who can see the project; writes are manager/admin.
    Because project progress is computed from properties, updating a phase's
    spent_budget changes the project's progress on the next read — no cache
    invalidation is needed.
    """

    serializer_class = ProjectPhaseSerializer
    queryset = ProjectPhase.objects.none()  # for schema model derivation

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy"):
            return [WRITE_PERMISSION()]
        return [IsAuthenticated()]

    def get_project(self):
        project = get_object_or_404(Project, pk=self.kwargs["project_pk"])
        user = self.request.user
        # Non-admins may only touch phases of projects in their own NGO.
        if user.role != Role.ADMIN and project.ngo_id != user.ngo_id:
            raise PermissionDenied("You do not have access to this project.")
        return project

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ProjectPhase.objects.none()
        return ProjectPhase.objects.filter(project=self.get_project())

    def perform_create(self, serializer):
        serializer.save(project=self.get_project())


class MilestoneViewSet(ProjectScopedViewSetMixin, viewsets.ModelViewSet):
    model = Milestone
    serializer_class = MilestoneSerializer
    filterset_class = MilestoneFilter
    queryset = Milestone.objects.none()  # for schema model derivation

    def base_queryset(self):
        return Milestone.objects.select_related("project")

    def get_permissions(self):
        # Milestones are managed by admins/managers; others read only.
        if self.action in ("create", "update", "partial_update", "destroy"):
            return [WRITE_PERMISSION()]
        return [IsAuthenticated()]
