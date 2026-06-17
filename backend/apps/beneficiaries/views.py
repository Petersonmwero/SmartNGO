from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from apps.accounts.permissions import IsFieldOfficer, IsProjectManager, IsSystemAdmin
from apps.common.mixins import ProjectScopedViewSetMixin

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
