"""Report CRUD with a draft -> submitted -> approved workflow, plus the
nested report-images multipart upload sub-resource."""
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.accounts.models import Role
from apps.accounts.permissions import (
    IsFieldOfficer,
    IsProjectManager,
    IsSystemAdmin,
)
from apps.common.mixins import ProjectScopedViewSetMixin

from .filters import ReportFilter
from .models import Report, ReportImage
from .serializers import ReportImageSerializer, ReportSerializer

AUTHOR_ROLES = IsSystemAdmin | IsProjectManager | IsFieldOfficer  # may create/edit
APPROVER_ROLES = IsSystemAdmin | IsProjectManager  # may approve


class ReportViewSet(ProjectScopedViewSetMixin, viewsets.ModelViewSet):
    model = Report
    serializer_class = ReportSerializer
    filterset_class = ReportFilter
    queryset = Report.objects.none()  # for schema model derivation

    def base_queryset(self):
        return Report.objects.select_related("officer", "project").prefetch_related(
            "images"
        )

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy", "submit"):
            return [AUTHOR_ROLES()]
        if self.action == "approve":
            return [APPROVER_ROLES()]
        return [IsAuthenticated()]

    # --- create / edit / delete ------------------------------------------
    def perform_create(self, serializer):
        project = serializer.validated_data["project"]
        self.validate_project_access(project)
        serializer.save(officer=self.request.user, status=Report.Status.DRAFT)

    def perform_update(self, serializer):
        if serializer.instance.status != Report.Status.DRAFT:
            raise ValidationError("Only draft reports can be edited.")
        self.validate_project_access(self._resolve_project(serializer))
        serializer.save()

    def perform_destroy(self, instance):
        if instance.status != Report.Status.DRAFT and self.request.user.role != Role.ADMIN:
            raise ValidationError("Only draft reports can be deleted.")
        instance.delete()

    # --- workflow transitions --------------------------------------------
    @action(detail=True, methods=["post"])
    def submit(self, request, pk=None):
        report = self.get_object()
        if report.officer_id != request.user.id and request.user.role != Role.ADMIN:
            raise PermissionDenied("Only the report's author can submit it.")
        if report.status != Report.Status.DRAFT:
            raise ValidationError("Only draft reports can be submitted.")
        report.status = Report.Status.SUBMITTED
        report.date_submitted = timezone.now()
        report.save(update_fields=["status", "date_submitted"])
        return Response(self.get_serializer(report).data)

    @action(detail=True, methods=["post"])
    def approve(self, request, pk=None):
        report = self.get_object()  # queryset already scopes managers to own NGO
        if report.status != Report.Status.SUBMITTED:
            raise ValidationError("Only submitted reports can be approved.")
        report.status = Report.Status.APPROVED
        report.save(update_fields=["status"])
        return Response(self.get_serializer(report).data)


class ReportImageViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Upload/list/delete images for a report.

    Routed at /api/v1/reports/<report_pk>/images/ (multipart).
    """

    serializer_class = ReportImageSerializer
    parser_classes = [MultiPartParser, FormParser]
    queryset = ReportImage.objects.none()  # for schema model derivation

    def get_permissions(self):
        if self.action in ("create", "destroy"):
            return [AUTHOR_ROLES()]
        return [IsAuthenticated()]

    def get_report(self):
        report = get_object_or_404(
            Report.objects.select_related("project"), pk=self.kwargs["report_pk"]
        )
        user = self.request.user
        if user.role == Role.ADMIN:
            return report
        if user.role == Role.OFFICER:
            if not report.project.assignments.filter(user=user).exists():
                raise PermissionDenied("You are not assigned to this report's project.")
            return report
        if report.project.ngo_id != user.ngo_id:
            raise PermissionDenied("This report is not in your NGO.")
        return report

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ReportImage.objects.none()
        return ReportImage.objects.filter(report=self.get_report())

    def perform_create(self, serializer):
        report = self.get_report()
        if report.status == Report.Status.APPROVED:
            raise ValidationError("Cannot add images to an approved report.")
        serializer.save(report=report)
