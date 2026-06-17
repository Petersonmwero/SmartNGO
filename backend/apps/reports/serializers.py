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


class ReportSerializer(serializers.ModelSerializer):
    images = ReportImageSerializer(many=True, read_only=True)
    officer_name = serializers.CharField(source="officer.full_name", read_only=True)

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
