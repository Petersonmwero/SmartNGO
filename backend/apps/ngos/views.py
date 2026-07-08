from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.accounts.permissions import IsSystemAdmin

from .models import NGO
from .serializers import NGOSerializer


class NGOViewSet(viewsets.ModelViewSet):
    """Full CRUD on NGOs — administrators only.

    The nested `public/` action is unauthenticated and returns only id + name,
    used by the registration screen to populate the NGO dropdown.
    """

    queryset = NGO.objects.all().order_by("name")
    serializer_class = NGOSerializer
    permission_classes = [IsSystemAdmin]
    filterset_fields = ["registration_no"]

    @action(
        detail=False,
        methods=["get"],
        url_path="public",
        permission_classes=[AllowAny],
    )
    def public_list(self, request):
        """Return id and name for every NGO — no authentication required.

        Used by the registration screen to populate the NGO dropdown without
        requiring the user to already have an account.
        """
        ngos = NGO.objects.only("id", "name").order_by("name")
        return Response([{"id": n.id, "name": n.name} for n in ngos])
