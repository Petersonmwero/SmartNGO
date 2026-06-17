from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from apps.accounts.permissions import IsProjectManager, IsSystemAdmin
from apps.common.mixins import ProjectScopedViewSetMixin

from .filters import IndicatorFilter
from .models import Indicator
from .serializers import IndicatorSerializer

# Indicators are managed by admins/managers; officers and donors read only.
WRITE_PERMISSION = IsSystemAdmin | IsProjectManager


class IndicatorViewSet(ProjectScopedViewSetMixin, viewsets.ModelViewSet):
    model = Indicator
    serializer_class = IndicatorSerializer
    filterset_class = IndicatorFilter
    queryset = Indicator.objects.none()  # for schema model derivation

    def base_queryset(self):
        return Indicator.objects.select_related("project")

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy"):
            return [WRITE_PERMISSION()]
        return [IsAuthenticated()]
