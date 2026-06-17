from rest_framework import viewsets

from apps.accounts.permissions import IsSystemAdmin

from .models import NGO
from .serializers import NGOSerializer


class NGOViewSet(viewsets.ModelViewSet):
    """Full CRUD on NGOs — administrators only."""

    queryset = NGO.objects.all().order_by("name")
    serializer_class = NGOSerializer
    permission_classes = [IsSystemAdmin]
    filterset_fields = ["registration_no"]
