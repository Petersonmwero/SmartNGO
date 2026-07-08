import csv
import io

from django.http import HttpResponse
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated

from apps.accounts.permissions import IsFieldOfficer, IsProjectManager, IsSystemAdmin
from apps.common.mixins import ProjectScopedViewSetMixin
from core.utils import compute_age

from .filters import BeneficiaryFilter
from .models import Beneficiary
from .serializers import BeneficiarySerializer

# Officers register beneficiaries, so they may write (on their assigned projects).
WRITE_PERMISSION = IsSystemAdmin | IsProjectManager | IsFieldOfficer


class BeneficiaryViewSet(ProjectScopedViewSetMixin, viewsets.ModelViewSet):
    model = Beneficiary
    serializer_class = BeneficiarySerializer
    filterset_class = BeneficiaryFilter
    queryset = Beneficiary.objects.none()  # for schema model derivation

    def base_queryset(self):
        # Soft-deleted beneficiaries are hidden.
        return Beneficiary.objects.filter(is_active=True).select_related("project")

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy"):
            return [WRITE_PERMISSION()]
        return [IsAuthenticated()]

    def perform_destroy(self, instance):
        # Soft delete — never hard delete beneficiaries.
        instance.is_active = False
        instance.save(update_fields=["is_active"])

    @action(detail=False, methods=["get"], url_path="export")
    def export(self, request):
        """Download all visible beneficiaries as a CSV file."""
        queryset = self.filter_queryset(self.get_queryset())

        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            ["ID", "Name", "Gender", "Date of Birth", "Age", "Phone", "Location", "Project", "Created At"]
        )
        for b in queryset.select_related("project"):
            age = compute_age(b.date_of_birth) if b.date_of_birth else ""
            writer.writerow([
                b.id,
                b.name,
                b.get_gender_display(),
                b.date_of_birth or "",
                age,
                b.phone,
                b.location,
                b.project.project_name,
                b.created_at.strftime("%Y-%m-%d"),
            ])

        response = HttpResponse(buffer.getvalue(), content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="beneficiaries.csv"'
        return response
