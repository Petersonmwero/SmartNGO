from decimal import Decimal

from rest_framework import serializers

from .models import Report, ReportImage

MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}

# The structured donor-reporting payload. Grouped so the freeze-on-approval
# rule and the serializer field list cannot drift apart.
STRUCTURED_FIELDS = [
    "activity_type",
    "linked_phase",
    "linked_milestone",
    "amount_spent",
    "expenditure_notes",
    "beneficiaries_reached",
    "beneficiaries_male",
    "beneficiaries_female",
    "beneficiaries_youth",
    "impact_description",
    "challenges_faced",
    "recommendations",
    "next_steps",
]


class ReportImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReportImage
        fields = ["id", "report", "image", "caption", "uploaded_at"]
        # report comes from the nested URL, not the body.
        read_only_fields = ["id", "report", "uploaded_at"]

    def validate_image(self, value):
        if value.size > MAX_IMAGE_SIZE:
            raise serializers.ValidationError("Image must be 5MB or smaller.")
        content_type = getattr(value, "content_type", None)
        if content_type and content_type not in ALLOWED_IMAGE_TYPES:
            raise serializers.ValidationError(
                "Unsupported image type. Allowed: JPEG, PNG, WEBP, GIF."
            )
        return value


def _round_coordinate(value, limit, label):
    """Round a GPS coordinate to the model's 7-dp precision and range-check.

    Devices report more decimal places than DECIMAL(10,7) can hold (e.g.
    -1.218110000000001), which would fail the field's max_digits check.
    Rounding first keeps every real-world coordinate valid; the range check
    guarantees at most 3 digits remain before the decimal point.
    """
    if value is None:
        return None
    rounded = round(float(value), 7)
    if not -limit <= rounded <= limit:
        raise serializers.ValidationError(
            f"{label} must be between -{limit} and {limit}."
        )
    # str() of the rounded float is its shortest representation, so the
    # resulting Decimal always fits DECIMAL(10,7).
    return Decimal(str(rounded))


class ReportSerializer(serializers.ModelSerializer):
    images = ReportImageSerializer(many=True, read_only=True)
    officer_name = serializers.CharField(source="officer.full_name", read_only=True)
    # Declared without digit limits so raw device coordinates reach the
    # validators below (the default DecimalField would reject them with
    # "no more than 10 digits" before validate_gps_* ever ran).
    gps_latitude = serializers.DecimalField(
        max_digits=None, decimal_places=None, required=False, allow_null=True
    )
    gps_longitude = serializers.DecimalField(
        max_digits=None, decimal_places=None, required=False, allow_null=True
    )

    def validate_gps_latitude(self, value):
        return _round_coordinate(value, 90, "Latitude")

    def validate_gps_longitude(self, value):
        return _round_coordinate(value, 180, "Longitude")

    def validate_amount_spent(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("Must be zero or a positive amount.")
        return value

    def _resolve(self, attrs, field):
        """Value of `field` after this write — incoming, else the stored one."""
        if field in attrs:
            return attrs[field]
        return getattr(self.instance, field, None)

    def validate(self, attrs):
        """Structured-reporting cross-field rules.

        Approved reports are frozen: a correction is filed as a new report so
        the donor ledger keeps an append-only history.
        """
        if (
            self.instance is not None
            and self.instance.status == Report.Status.APPROVED
            and any(field in attrs for field in STRUCTURED_FIELDS)
        ):
            raise serializers.ValidationError(
                "An approved report cannot be edited. File a new report instead."
            )

        project = self._resolve(attrs, "project")
        for field in ("linked_phase", "linked_milestone"):
            link = attrs.get(field)
            if link is not None and project is not None and link.project_id != project.id:
                raise serializers.ValidationError(
                    {field: "Must belong to the same project as the report."}
                )

        reached = self._resolve(attrs, "beneficiaries_reached") or 0
        male = self._resolve(attrs, "beneficiaries_male") or 0
        female = self._resolve(attrs, "beneficiaries_female") or 0
        youth = self._resolve(attrs, "beneficiaries_youth") or 0
        if male + female > reached:
            raise serializers.ValidationError(
                {
                    "beneficiaries_reached": (
                        "Male plus female cannot exceed the total reached."
                    )
                }
            )
        # Youth cuts across the gender split rather than adding to it, so it
        # is bounded by the total on its own.
        if youth > reached:
            raise serializers.ValidationError(
                {"beneficiaries_youth": "Cannot exceed the total reached."}
            )
        return attrs

    class Meta:
        model = Report
        fields = [
            "id",
            "project",
            "officer",
            "officer_name",
            "title",
            "description",
            "gps_latitude",
            "gps_longitude",
            "report_type",
            "status",
            "date_submitted",
            "images",
            *STRUCTURED_FIELDS,
            "posted_at",
        ]
        # officer is the author (set server-side); status/date_submitted/
        # posted_at are driven by the submit/approve workflow actions, not
        # direct writes.
        read_only_fields = [
            "id",
            "officer",
            "status",
            "date_submitted",
            "posted_at",
        ]
