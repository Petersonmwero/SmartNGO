from decimal import Decimal

from rest_framework import serializers

from .models import Report, ReportImage

MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


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
        ]
        # officer is the author (set server-side); status/date_submitted are
        # driven by the submit/approve workflow actions, not direct writes.
        read_only_fields = [
            "id",
            "officer",
            "status",
            "date_submitted",
        ]
