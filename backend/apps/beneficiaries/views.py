import csv
import io

from django.http import HttpResponse
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsFieldOfficer, IsProjectManager, IsSystemAdmin
from apps.common.mixins import ProjectScopedViewSetMixin
from core.utils import compute_age

from .filters import BeneficiaryFilter
from .kenya_locations import (
    CONSTITUENCY_WARDS,
    COUNTY_CONSTITUENCIES,
    KENYA_COUNTIES,
    LOCATION_SUBLOCATION,
    locations_for_ward,
)
from .models import Beneficiary
from .serializers import BeneficiarySerializer


class _LocationListResponse(serializers.Serializer):
    """Schema-only serializer for the Kenya locations envelope."""

    status = serializers.CharField()
    data = serializers.ListField(child=serializers.CharField())


class KenyaLocationView(APIView):
    """Public reference data for the cascading Kenya location picker.

    Exactly one level is selected per call:
    ``?counties=true`` → all 47 counties (alphabetical);
    ``?county=<name>`` → constituencies; ``?constituency=<name>`` → wards;
    ``?constituency=<name>&ward=<name>`` → locations; ``?location=<name>`` →
    sub-locations. The location lookup takes the constituency too, so
    same-named wards in different constituencies resolve correctly; passing
    ``ward`` without ``constituency`` degrades to generated locations.
    Unknown names (and levels without data yet) return an empty list rather
    than an error, so the client can degrade gracefully.
    """

    permission_classes = [AllowAny]

    @extend_schema(
        parameters=[
            OpenApiParameter("counties", str, description="Any value: list all counties"),
            OpenApiParameter("county", str, description="List constituencies of this county"),
            OpenApiParameter("constituency", str, description="List wards of this constituency (or, with ward, scope its locations)"),
            OpenApiParameter("ward", str, description="With constituency: list that ward's locations"),
            OpenApiParameter("location", str, description="List sub-locations of this location"),
        ],
        responses={200: _LocationListResponse},
        operation_id="kenya_locations",
    )
    def get(self, request):
        query = request.query_params

        if "counties" in query:
            return Response({"status": "success", "data": sorted(KENYA_COUNTIES)})

        county = query.get("county")
        if county:
            return self._ok(COUNTY_CONSTITUENCIES.get(county, []))

        # Ward locations are keyed by (constituency, ward), so this must be
        # checked before the bare-constituency (→ wards) case below.
        ward = query.get("ward")
        if ward:
            return self._ok(locations_for_ward(query.get("constituency", ""), ward))

        constituency = query.get("constituency")
        if constituency:
            return self._ok(CONSTITUENCY_WARDS.get(constituency, []))

        location = query.get("location")
        if location:
            return self._ok(LOCATION_SUBLOCATION.get(location, []))

        return Response(
            {
                "status": "error",
                "message": (
                    "Provide: counties, county, constituency, ward "
                    "(with constituency), or location parameter"
                ),
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    @staticmethod
    def _ok(data):
        return Response({"status": "success", "data": data})

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
                b.full_location,
                b.project.project_name,
                b.created_at.strftime("%Y-%m-%d"),
            ])

        response = HttpResponse(buffer.getvalue(), content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="beneficiaries.csv"'
        return response
